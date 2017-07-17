/** 缓存图片
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

typedef NS_ENUM(NSInteger, SDImageCacheType) {
    /** 没有缓存, 需要加载网络图片 */
    SDImageCacheTypeNone,
    /** 从磁盘中获取到图片 */
    SDImageCacheTypeDisk,
    /** 从内存中获取到图片 */
    SDImageCacheTypeMemory
};

// 定义的一个参数类型 用来成功的回调
typedef void(^SDWebImageQueryCompletedBlock)(UIImage *image, SDImageCacheType cacheType);

typedef void(^SDWebImageCheckCacheCompletionBlock)(BOOL isInCache);
// 计算本地磁盘所有图片总大小 数量
typedef void(^SDWebImageCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);

/**
 * SDImageCache维护一个内存缓存和一个可选的磁盘缓存。磁盘缓存执行写操作
 * 异步所以不添加不必要的延迟到UI。
 */
@interface SDImageCache : NSObject

/**
 * 是否解压缩图片，默认为YES
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 * 是否禁用iCloud备份， 默认为YES
 */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

/**
 * 是否缓存到内存中，默认为YES
 */
@property (assign, nonatomic) BOOL shouldCacheImagesInMemory;

/**
 * 设置内存的最大缓存是多少，这个是以像素为单位的
 */
@property (assign, nonatomic) NSUInteger maxMemoryCost;

/**
 * 来设置内存的最大缓存数量是多少。
 */
@property (assign, nonatomic) NSUInteger maxMemoryCountLimit;

/**
 * 时间的最大长度保持图像缓存中,在几秒钟内, 默认 60 * 60 * 24 * 7 一周时间
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * 最大的缓存尺寸，单位为字节
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

/**
 * Returns global shared cache instance
 *
 * @return SDImageCache global instance
 */
+ (SDImageCache *)sharedImageCache;

/**
 * Init a new cache store with a specific namespace
 *
 * @param ns The namespace to use for this cache store
 */
- (id)initWithNamespace:(NSString *)ns;

/**
 * Init a new cache store with a specific namespace and directory
 *
 * @param ns        The namespace to use for this cache store
 * @param directory Directory to cache disk images in
 */
- (id)initWithNamespace:(NSString *)ns diskCacheDirectory:(NSString *)directory;

-(NSString *)makeDiskCachePath:(NSString*)fullNamespace;

/**
 * 添加自定义的缓存路径
 */
- (void)addReadOnlyCachePath:(NSString *)path;

/**
 * Store an image into memory and disk cache at the given key.
 *
 * @param image The image to store
 * @param key   The unique image cache key, usually it's image absolute URL
 */
- (void)storeImage:(UIImage *)image forKey:(NSString *)key;

/**
 * Store an image into memory and optionally disk cache at the given key.
 *
 * @param image  The image to store
 * @param key    The unique image cache key, usually it's image absolute URL
 * @param toDisk Store the image to disk cache if YES
 */
- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk;

/**
 * Store an image into memory and optionally disk cache at the given key.
 *
 * @param image       The image to store
 * @param recalculate BOOL indicates if imageData can be used or a new data should be constructed from the UIImage
 * @param imageData   The image data as returned by the server, this representation will be used for disk storage
 *                    instead of converting the given image object into a storable/compressed image format in order
 *                    to save quality and CPU
 * @param key         The unique image cache key, usually it's image absolute URL
 * @param toDisk      Store the image to disk cache if YES
 */
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk;

/**
 * 保存到本地磁盘中
 * @param imageData image 2进制数据
 * @param key (一般指的是图片的url string)
 */
- (void)storeImageDataToDisk:(NSData *)imageData forKey:(NSString *)key;

/**
 * 异步查询磁盘高速缓存。
 *
 * 查询缓存，默认使用方法queryDiskCacheForKey:done:，如果此方法返回nil，则说明缓存中现在还没有这张照片，因此你需要得到并缓存这张图片。缓存key是缓存图片的程序唯一的标识符，一般使用图片的完整URL。
 * 如果不想SDImageCache查询磁盘缓存，你可以调用另一个方法：imageFromMemoryCacheForKey:。
 * 返回值为NSOpration，单独使用SDImageCache没用，但是使用SDWebImageManager就可以对多个任务的优先级、依赖，并且可以取消。
 * 自定义@autoreleasepool，autoreleasepool代码段里面有大量的内存消耗操作，自定义autoreleasepool可以及时地释放掉内存
 */
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(SDWebImageQueryCompletedBlock)doneBlock;

/**
 * 首先根据key(一般指的是图片的url string)去内存缓存获取image
 *
 * @param key The unique key used to store the wanted image
 */
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key;

/**
 * Query the disk cache synchronously after checking the memory cache.
 * 查询磁盘缓存同步后检查内存缓存。根据key（一般指的是图片的url）首先去内存中查找, 没有再去磁盘查找
 *
 * @param key The unique key used to store the wanted image
 */
- (UIImage *)imageFromDiskCacheForKey:(NSString *)key;

/**
 * Remove the image from memory and disk cache asynchronously
 * 异步移除释放掉内存中和磁盘缓存的图片
 *
 * @param key The unique image cache key
 */
- (void)removeImageForKey:(NSString *)key;


/**
 * Remove the image from memory and disk cache asynchronously
 * 异步移除释放掉内存中和磁盘缓存的图片, 有一个成功的回调
 *
 * @param key             The unique image cache key
 * @param completion      An block that should be executed after the image has been removed (optional)
 */
- (void)removeImageForKey:(NSString *)key withCompletion:(SDWebImageNoParamsBlock)completion;

/**
 * Remove the image from memory and optionally disk cache asynchronously
 * 异步移除释放掉内存中(和磁盘)缓存的图片
 *
 * @param key      The unique image cache key
 * @param fromDisk Also remove cache entry from disk if YES
 */
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk;

/**
 * Remove the image from memory and optionally disk cache asynchronously
 * 异步移除释放掉内存中(和磁盘)缓存的图片, 有一个成功的回调
 *
 * @param key             The unique image cache key
 * @param fromDisk        Also remove cache entry from disk if YES
 * @param completion      An block that should be executed after the image has been removed (optional)
 */
- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(SDWebImageNoParamsBlock)completion;

/**
 * Clear all memory cached images
 * 清空所有的内存图片
 */
- (void)clearMemory;

/**
 * Clear all disk cached images. Non-blocking method - returns immediately.
 * 清理磁盘, 回调. 非阻塞线程
 * @param completion    An block that should be executed after cache expiration completes (optional)
 */
- (void)clearDiskOnCompletion:(SDWebImageNoParamsBlock)completion;

/**
 * Clear all disk cached images
 * 清理磁盘
 * @see clearDiskOnCompletion:
 */
- (void)clearDisk;

/**
 * Remove all expired cached image from disk. Non-blocking method - returns immediately.
 * 程序被终止
 * @param completionBlock An block that should be executed after cache expiration completes (optional)
 */
- (void)cleanDiskWithCompletionBlock:(SDWebImageNoParamsBlock)completionBlock;

/** 清理磁盘
 */
- (void)cleanDisk;

/** 获取磁盘目录下图片的缓存大小
 */
- (NSUInteger)getSize;

/** 图片数量
 */
- (NSUInteger)getDiskCount;

/** 异步计算磁盘高速缓存的大小。
 */
- (void)calculateSizeWithCompletionBlock:(SDWebImageCalculateSizeBlock)completionBlock;

/** 异步检查图像是否存在于磁盘(不加载图片)
 */
- (void)diskImageExistsWithKey:(NSString *)key completion:(SDWebImageCheckCacheCompletionBlock)completionBlock;

/**
 *  Check if image exists in disk cache already (does not load the image)
 *
 *  @param key the key describing the url
 *
 *  @return YES if an image exists for the given key
 */
- (BOOL)diskImageExistsWithKey:(NSString *)key;

/**
 *  Get the cache path for a certain key (needs the cache path root folder)
 *
 *  @param key  the key (can be obtained from url using cacheKeyForURL)
 *  @param path the cache path root folder
 *
 *  @return the cache path
 */
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path;

/**
 *  Get the default cache path for a certain key
 *
 *  @param key the key (can be obtained from url using cacheKeyForURL)
 *
 *  @return the default cache path
 */
- (NSString *)defaultCachePathForKey:(NSString *)key;

@end
