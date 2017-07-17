#import "SDImageCache.h"
#import "SDWebImageDecoder.h"
#import "UIImage+MultiFormat.h"
#import <CommonCrypto/CommonDigest.h>

@interface AutoPurgeCache : NSCache

@end

@implementation AutoPurgeCache

- (id)init
{
    self = [super init];
    if (self) {
        // 内存异常通知 清理缓存
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAllObjects) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

@end

// 图片保存的周期 1周
static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week
// PNG signature bytes and data (below)
// png 文件头格式字节
static unsigned char kPNGSignatureBytes[8] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
static NSData *kPNGSignatureData = nil;

BOOL ImageDataHasPNGPreffix(NSData *data);

BOOL ImageDataHasPNGPreffix(NSData *data) {
    NSUInteger pngSignatureLength = [kPNGSignatureData length];
    if ([data length] >= pngSignatureLength) {
        if ([[data subdataWithRange:NSMakeRange(0, pngSignatureLength)] isEqualToData:kPNGSignatureData]) {
            return YES;
        }
    }

    return NO;
}

// 将图片像素大小作为该对象的cost值
/** 注意：FOUNDATION_STATIC_INLINE表示该函数是一个具有文件内部访问权限的内联函数，所谓的内联函数就是建议编译器在调用时将函数展开。建议的意思就是说编译器不一定会按照你的建议做。因此内联函数尽量不要写的太复杂。**/
FOUNDATION_STATIC_INLINE NSUInteger SDCacheCostForImage(UIImage *image) {
    return image.size.height * image.size.width * image.scale * image.scale;
}

@interface SDImageCache ()

// 内存容器
@property (strong, nonatomic) NSCache *memCache;
// disk缓存路径
@property (strong, nonatomic) NSString *diskCachePath;
// 自定义的读取路径，这是一个数组，我们可以通过addReadOnlyCachePath:这个方法往里边添加路径。当我们读取读片的时候，这个数组的路径也会作为数据源
@property (strong, nonatomic) NSMutableArray *customPaths;
// 异步串行地清理disk缓存
@property (SDDispatchQueueSetterSementics, nonatomic) dispatch_queue_t ioQueue;

@end


@implementation SDImageCache {
    NSFileManager *_fileManager;
}

+ (SDImageCache *)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

/**
 * 初始化缓存位置, 默认
 */
- (id)init {
    return [self initWithNamespace:@"default"];
}

- (id)initWithNamespace:(NSString *)ns {
    NSString *path = [self makeDiskCachePath:ns];
    return [self initWithNamespace:ns diskCacheDirectory:path];
}

- (id)initWithNamespace:(NSString *)ns diskCacheDirectory:(NSString *)directory {
    if ((self = [super init])) {
        NSString *fullNamespace = [@"com.hackemist.SDWebImageCache." stringByAppendingString:ns];
        NSLog(@"directory: %@", directory);
        // initialise PNG signature data
        // 初始化PNG标记数据
        kPNGSignatureData = [NSData dataWithBytes:kPNGSignatureBytes length:8];

        // Create IO serial queue
        // 生成一个串行队列，队列中的block按照先进先出（FIFO）的顺序去执行。第一个参数是队列的名称，在调试程序时会非常有用，所有尽量不要重名了, 用来清理disk图片
        _ioQueue = dispatch_queue_create("com.hackemist.SDWebImageCache", DISPATCH_QUEUE_SERIAL);

        // Init default values
        // 初始化默认的最大缓存时间
        _maxCacheAge = kDefaultCacheMaxCacheAge;

        // Init the memory cache
        // 初始化内存缓存，详见接下来解析的内存缓存类
        _memCache = [[AutoPurgeCache alloc] init];
        _memCache.name = fullNamespace;

        // Init the disk cache
        // 初始化disk缓存
        if (directory != nil) {
            _diskCachePath = [directory stringByAppendingPathComponent:fullNamespace];
        } else {
            NSString *path = [self makeDiskCachePath:ns];
            _diskCachePath = path;
        }
        
        NSLog(@"paths: %@", _diskCachePath);
        // Set decompression to YES
        // 设置默认解压缩图片
        _shouldDecompressImages = YES;

        // memory cache enabled
        // 设置默认开启内存缓存
        _shouldCacheImagesInMemory = YES;

        // Disable iCloud
        // 设置默认不使用iCloud
        _shouldDisableiCloud = YES;

        dispatch_sync(_ioQueue, ^{
            _fileManager = [NSFileManager new];
        });

#if TARGET_OS_IOS
        // Subscribe to app events
        // app事件注册，内存警告事件，程序被终止事件，已经进入后台模式事件，详见后文的解析：app事件注册。
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundCleanDisk)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SDDispatchQueueRelease(_ioQueue);
}

// 添加自定义的缓存路径
- (void)addReadOnlyCachePath:(NSString *)path {
    if (!self.customPaths) {
        self.customPaths = [NSMutableArray new];
    }

    if (![self.customPaths containsObject:path]) {
        [self.customPaths addObject:path];
    }
}

// 返回缓存完整路径，其中文件名是根据key值生成的MD5值，具体生成方法见后文解析
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path {
    // 生成MD5 文件名
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}

// 返回图片全路径
- (NSString *)defaultCachePathForKey:(NSString *)key {
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

#pragma mark SDImageCache (private)
// MD5计算 生成文件名
- (NSString *)cachedFileNameForKey:(NSString *)key {
    const char *str = [key UTF8String];
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [[key pathExtension] isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", [key pathExtension]]];

    return filename;
}

#pragma mark ImageCache

// 缓存路径
// /Users/taojian/Library/Developer/CoreSimulator/Devices/278AE2A9-4BC4-4D49-B06B-6F9631EF8163/data/Containers/Data/Application/BE1826C7-FA12-4356-80E0-DBCD9D98A0F0/Library/Caches/default
-(NSString *)makeDiskCachePath:(NSString*)fullNamespace{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:fullNamespace];
}

/**
 存储一个图片到缓存中，可以使用方法storeImage:forKey:method:，默认，图片既会存储到内存缓存中，也会异步地保存到disk缓存中。如果只想使用内存缓存，也可以使用另外一个方法storeImage:forKey:toDisk，第三个参数传入false值就好了。
 */
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk {
    // 过滤极端情况
    if (!image || !key) {
        return;
    }
    // 如果缓存到内存中
    if (self.shouldCacheImagesInMemory) {
        // 图片的像素大小
        NSUInteger cost = SDCacheCostForImage(image);
        [self.memCache setObject:image forKey:key cost:cost];
    }

    // 是否保存到disk中
    if (toDisk) {
        // 异步子线程保存到disk中
        dispatch_async(self.ioQueue, ^{
            NSData *data = imageData;
            NSLog(@"%@", [NSThread currentThread]);
            if (image && (recalculate || !data)) {
#if TARGET_OS_IPHONE
                // 我们需要判断图片是PNG还是JPEG格式。PNG图片很容易检测，因为它们拥有一个独特的签名<http://www.w3.org/TR/PNG-Structure.html>。PNG文件的前八字节经常包含如下(十进制)的数值：137 80 78 71 13 10 26 10
                // 如果imageData为nil（也就是说，如果试图直接保存一个UIImage或者图片是由下载转换得来）并且图片有alpha通道，我们将认为它是PNG文件以避免丢失透明度信息。
                int alphaInfo = CGImageGetAlphaInfo(image.CGImage);
                BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                                  alphaInfo == kCGImageAlphaNoneSkipFirst ||
                                  alphaInfo == kCGImageAlphaNoneSkipLast);
                BOOL imageIsPng = hasAlpha;

                // 但是如果我们有image data，我们将查询数据前缀
                if ([imageData length] >= [kPNGSignatureData length]) {
                    imageIsPng = ImageDataHasPNGPreffix(imageData);
                }

                if (imageIsPng) {
                    data = UIImagePNGRepresentation(image);
                }
                else {
                    data = UIImageJPEGRepresentation(image, (CGFloat)1.0);
                }
#else
                data = [NSBitmapImageRep representationOfImageRepsInArray:image.representations usingType: NSJPEGFileType properties:nil];
#endif
            }

            [self storeImageDataToDisk:data forKey:key];
        });
    }
}

/** 存储图片, storeImage:recalculateFromImage:imageData:forKey:toDisk:*/
- (void)storeImage:(UIImage *)image forKey:(NSString *)key {
    [self storeImage:image recalculateFromImage:YES imageData:nil forKey:key toDisk:YES];
}

/** 存储图片, storeImage:recalculateFromImage:imageData:forKey:toDisk: */
- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk {
    [self storeImage:image recalculateFromImage:YES imageData:nil forKey:key toDisk:toDisk];
}

// 保存到本地disk中
- (void)storeImageDataToDisk:(NSData *)imageData forKey:(NSString *)key {
    
    if (!imageData) {
        return;
    }
    
    if (![_fileManager fileExistsAtPath:_diskCachePath]) {
        [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    // 获得对应图像key的完整缓存路径
    NSString *cachePathForKey = [self defaultCachePathForKey:key];
    // 转换成NSUrl
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
    
    // 保存文件到disk中
    [_fileManager createFileAtPath:cachePathForKey contents:imageData attributes:nil];
    
    // iCloud备份
    if (self.shouldDisableiCloud) {
        [fileURL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

// 查找key是否在本地disk中存在
- (BOOL)diskImageExistsWithKey:(NSString *)key {
    BOOL exists = NO;
    // NSFileManager 中线程安全, 查找当前key是否在本地disk
    exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForKey:key]];

    if (!exists) {
        // NSFileManager 中线程安全, 去除扩展名, 查找当前key是否在本地disk
        exists = [[NSFileManager defaultManager] fileExistsAtPath:[[self defaultCachePathForKey:key] stringByDeletingPathExtension]];
    }
    
    return exists;
}

// 异步子线程查找key是否存在本地disk中
- (void)diskImageExistsWithKey:(NSString *)key completion:(SDWebImageCheckCacheCompletionBlock)completionBlock {
    // 异步子线程
    dispatch_async(_ioQueue, ^{
        // NSFileManager 中线程安全, 查找当前key是否在本地disk
        BOOL exists = [_fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];

        if (!exists) {
            // NSFileManager 中线程安全, 去除扩展名, 再查找当前key是否在本地disk
            exists = [_fileManager fileExistsAtPath:[[self defaultCachePathForKey:key] stringByDeletingPathExtension]];
        }

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

// 根据key（一般指的是图片的url）去内存缓存获取image
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key {
    return [self.memCache objectForKey:key];
}

// 根据key（一般指的是图片的url）首先去内存中查找, 没有再去disk查找
- (UIImage *)imageFromDiskCacheForKey:(NSString *)key {

    // 内存中查找
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        return image;
    }

    // 再去disk中查找
    UIImage *diskImage = [self diskImageForKey:key];
    // 找到写到内存中, 并且返回
    if (diskImage && self.shouldCacheImagesInMemory) {
        NSUInteger cost = SDCacheCostForImage(diskImage);
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }

    return diskImage;
}

// 从默认路径和只读的bundle路径中搜索图片
/**
 上面代码段是从disk获取图片的代码。得到图片对应的NSData后，还要经过如下步骤，才能返回对应的图片：
 
 根据图片的不同种类，生成对应的UIImage
 根据key值，调整image的scale值
 如果设置图片需要解压缩，则还需对UIImage进行解码
 */
- (NSData *)diskImageDataBySearchingAllPathsForKey:(NSString *)key {
    
    // /Users/taojian/Library/Developer/CoreSimulator/Devices/278AE2A9-4BC4-4D49-B06B-6F9631EF8163/data/Containers/Data/Application/116B1C95-FCA3-4BD9-9C82-A038510CB3D5/Library/Caches/default/com.hackemist.SDWebImageCache.default/0eb6bebf2aabaea7411761b7496064bc.jpg@1242w_696h_1e_1c_40q
    // 获取key的全路径
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSLog(@"%@", defaultPath);
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    // 如果全路径有值(说明本地有图片)直接返回
    if (data) {
        return data;
    }

    // 否则去掉扩展名再去查找
    data = [NSData dataWithContentsOfFile:[defaultPath stringByDeletingPathExtension]];
    // 如果去掉扩展名有值(说明本地有图片)直接返回
    if (data) {
        return data;
    }

    // 否则 再去自定义的路径下查找
    NSArray *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) {
            return imageData;
        }

        // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
        // checking the key with and without the extension
        imageData = [NSData dataWithContentsOfFile:[filePath stringByDeletingPathExtension]];
        if (imageData) {
            return imageData;
        }
    }

    return nil;
}

// 根据key 去disk缓存获取image
- (UIImage *)diskImageForKey:(NSString *)key {
    NSData *data = [self diskImageDataBySearchingAllPathsForKey:key];
    // 如果找到了直接转换对象返回
    if (data) {
        UIImage *image = [UIImage sd_imageWithData:data];
        image = [self scaledImageForKey:key image:image];
        // 是否解压缩图片，默认为YES
        if (self.shouldDecompressImages) {
            image = [UIImage decodedImageWithImage:image];
        }
        return image;
    }
    else { // 找不到返回nil
        return nil;
    }
}

- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image {
    return SDScaledImageForKey(key, image);
}

/**
 查询缓存，默认使用方法queryDiskCacheForKey:done:，如果此方法返回nil，则说明缓存中现在还没有这张照片，因此你需要得到并缓存这张图片。缓存key是缓存图片的程序唯一的标识符，一般使用图片的完整URL。
 如果不想SDImageCache查询disk缓存，你可以调用另一个方法：imageFromMemoryCacheForKey:。
 返回值为NSOpration，单独使用SDImageCache没用，但是使用SDWebImageManager就可以对多个任务的优先级、依赖，并且可以取消。
 自定义@autoreleasepool，autoreleasepool代码段里面有大量的内存消耗操作，自定义autoreleasepool可以及时地释放掉内存
 */
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(SDWebImageQueryCompletedBlock)doneBlock {
    // 极端情况
    if (!doneBlock) {
        return nil;
    }

    if (!key) {
        doneBlock(nil, SDImageCacheTypeNone);
        return nil;
    }

    // 首先查询内存缓存... 找到直接返回
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        doneBlock(image, SDImageCacheTypeMemory);
        return nil;
    }

    NSOperation *operation = [NSOperation new];
    // 异步线程
    dispatch_async(self.ioQueue, ^{
        // 因为是异步所以有可能创建完就被取消了, 所以需要做一个判断
        if (operation.isCancelled) {
            return;
        }

        // 自动释放池:
        @autoreleasepool {
            // 根据key 去disk缓存获取image
            UIImage *diskImage = [self diskImageForKey:key];
            if (diskImage && self.shouldCacheImagesInMemory) {
                // 将图片保存到内存中，并把图片像素大小作为该对象的cost值
                NSUInteger cost = SDCacheCostForImage(diskImage);
                [self.memCache setObject:diskImage forKey:key cost:cost];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                doneBlock(diskImage, SDImageCacheTypeDisk);
            });
        }
    });

    return operation;
}

/** 数据全部移除, 没回调 */
- (void)removeImageForKey:(NSString *)key {
    [self removeImageForKey:key withCompletion:nil];
}

/** 数据全部移除, 有回调 */
- (void)removeImageForKey:(NSString *)key withCompletion:(SDWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

/** 移除内存数据，是否也移除disk数据, 没回调 */
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk {
    [self removeImageForKey:key fromDisk:fromDisk withCompletion:nil];
}

/** 移除内存数据，是否也移除disk数据, 有回调 */
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(SDWebImageNoParamsBlock)completion {
    // 极端情况
    if (key == nil) {
        return;
    }

    // 移除内存数据
    if (self.shouldCacheImagesInMemory) {
        [self.memCache removeObjectForKey:key];
    }

    // 是否移除disk数据
    if (fromDisk) {
        // 异步移除disk全部图片
        dispatch_async(self.ioQueue, ^{
            [_fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion){
        completion();
    }
    
}
// Mem Cache settings
- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost {
    self.memCache.totalCostLimit = maxMemoryCost;
}

- (NSUInteger)maxMemoryCost {
    return self.memCache.totalCostLimit;
}

- (NSUInteger)maxMemoryCountLimit {
    return self.memCache.countLimit;
}

- (void)setMaxMemoryCountLimit:(NSUInteger)maxCountLimit {
    self.memCache.countLimit = maxCountLimit;
}

// 清空所有的内存图片
- (void)clearMemory {
    [self.memCache removeAllObjects];
}

// 清理disk
- (void)clearDisk {
    [self clearDiskOnCompletion:nil];
}

// 清理disk, 有回调
- (void)clearDiskOnCompletion:(SDWebImageNoParamsBlock)completion
{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:self.diskCachePath error:nil];
        [_fileManager createDirectoryAtPath:self.diskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

// 程序被终止
- (void)cleanDisk {
    [self cleanDiskWithCompletionBlock:nil];
}

/**
 * 异步删除所有过期的缓存从disk映像。非阻塞方法立即返回。
 先清除已超过最大缓存时间的缓存文件（最大缓存时间默认为一星期）
 在第一轮清除的过程中保存文件属性，特别是缓存文件大小
 在第一轮清除后，如果设置了最大缓存并且保留下来的disk缓存文件仍然超过了配置的最大缓存，那么进行第二轮以大小为基础的清除。
 首先删除最老的文件，直到达到期望的总的缓存大小，即最大缓存的一半。
 */
- (void)cleanDiskWithCompletionBlock:(SDWebImageNoParamsBlock)completionBlock {
    // 异步串行线程
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        // 使用目录枚举器获取缓存文件的三个重要属性：(1)URL是否为文件夹；(2)内容最后更新日期；(3)文件总的分配大小。
        NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];

        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];

        // 计算过期日期，默认为一星期前的缓存文件认为是过期的。
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
        NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;

        // 枚举缓存目录的所有文件，此循环有两个目的：
        //
        //  1. 清除超过过期日期的文件。
        //  2. 为以大小为基础的第二轮清除保存文件属性。
        NSMutableArray *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];

            // 跳过目录.
            if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }

            // Remove files that are older than the expiration date;
            // 记录超过过期日期的文件;
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelete addObject:fileURL];
                continue;
            }

            // Store a reference to this file and account for its total size.
            // 保存保留下来的文件的引用并计算文件总的大小。
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += [totalAllocatedSize unsignedIntegerValue];
            [cacheFiles setObject:resourceValues forKey:fileURL];
        }
        
        //清除记录的过期缓存文件
        for (NSURL *fileURL in urlsToDelete) {
            [_fileManager removeItemAtURL:fileURL error:nil];
        }

        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // 如果我们保留下来的disk缓存文件仍然超过了配置的最大大小，那么进行第二轮以大小为基础的清除。
        // size-based cleanup pass.  We delete the oldest files first.
        // 我们首先删除最老的文件。前提是我们设置了最大缓存

        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            // 此轮清除的目标是最大缓存的一半。
            const NSUInteger desiredCacheSize = self.maxCacheSize / 2;

            // Sort the remaining cache files by their last modification time (oldest first).
            // 用它们最后更新时间排序保留下来的缓存文件（最老的最先被清除）。
            NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                            usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                            }];

            // Delete files until we fall below our desired cache size.
            // 删除文件，直到我们达到期望的总的缓存大小。
            for (NSURL *fileURL in sortedFiles) {
                if ([_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];

                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

/**
 当收到UIApplicationDidEnterBackgroundNotification时，在手机系统后台进行如上面描述的异步disk缓存清理。这里利用Objective－C的动态语言特性，得到UIApplication的单例sharedApplication，使用sharedApplication开启后台任务cleanDiskWithCompletionBlock:。
 */
- (void)backgroundCleanDisk {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        // 清理任何未完成的任务作业，标记完全停止或结束任务。
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    // 开始长时间后台运行的任务并且立即return。
    [self cleanDiskWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

#pragma mark - Cache Info
// 获取disk目录下图片的缓存大小
- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    NSLog(@"*****************---------size: %zd", size);
    return size;
}

// 图片数量
- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtPath:self.diskCachePath];
        count = [[fileEnumerator allObjects] count];
    });
    NSLog(@"*****************---------count: %zd", count);
    return count;
}

// 异步计算disk高速缓存的大小。 getDiskCount, getSize的合体
- (void)calculateSizeWithCompletionBlock:(SDWebImageCalculateSizeBlock)completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];

    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;

        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles // 表示不遍历隐藏文件
                                                                 errorHandler:NULL];

        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += [fileSize unsignedIntegerValue];
            fileCount += 1;
        }
        NSLog(@"*****************---------fileCount: %zd", fileCount);
        NSLog(@"*****************---------totalSize: %zd", totalSize);

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

@end
