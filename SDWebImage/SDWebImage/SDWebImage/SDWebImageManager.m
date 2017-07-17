/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageManager.h"
#import <objc/message.h>

@interface SDWebImageCombinedOperation : NSObject <SDWebImageOperation>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (copy, nonatomic) SDWebImageNoParamsBlock cancelBlock;
@property (strong, nonatomic) NSOperation *cacheOperation;

@end

@interface SDWebImageManager ()

@property (strong, nonatomic, readwrite) SDImageCache *imageCache;
@property (strong, nonatomic, readwrite) SDWebImageDownloader *imageDownloader;
@property (strong, nonatomic) NSMutableSet *failedURLs;
// 正在发送的Operations
@property (strong, nonatomic) NSMutableArray *runningOperations;

@end

@implementation SDWebImageManager

// 单例
+ (id)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    // 初始化缓存器
    SDImageCache *cache = [SDImageCache sharedImageCache];
    // 初始化下载器
    SDWebImageDownloader *downloader = [SDWebImageDownloader sharedDownloader];
    return [self initWithCache:cache downloader:downloader];
}

// 允许指定缓存的实例和图片下载器使用图片管理器。
- (instancetype)initWithCache:(SDImageCache *)cache downloader:(SDWebImageDownloader *)downloader {
    if ((self = [super init])) {
        // 保存缓存器
        _imageCache = cache;
        // 保存下载器
        _imageDownloader = downloader;
        // 初始化一个加载失败的集合, 如果选择的是SDWebImageRetryFailed这个模式失败后需要再次发送请求, 所以把url保存起来备用
        _failedURLs = [NSMutableSet new];
        // 正在发送的Operations
        _runningOperations = [NSMutableArray new];
    }
    return self;
}

// 根据URL 来获取其地址, 可以过滤URL中一些其他字符
- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!url) {
        return @"";
    }
    
    /*
     SDWebImageManager.sharedManager.cacheKeyFilter = ^(NSURL *url) {
     url = [[NSURL alloc] initWithScheme:url.scheme host:url.host path:url.path];
     return [url absoluteString];
     };
     */
    if (self.cacheKeyFilter) {
        // 过滤URL 返回地址
        return self.cacheKeyFilter(url);
    } else {
        // 返回地址
        return [url absoluteString];
    }
}

// 检查当前URL 在内存或本地磁盘中是否存在缓存
- (BOOL)cachedImageExistsForURL:(NSURL *)url {
    // 根据url 取其内部的地址当做key
    NSString *key = [self cacheKeyForURL:url];
    // 根据key(URL地址)在内存中查找是否存在(key)对应的缓存
    if ([self.imageCache imageFromMemoryCacheForKey:key] != nil) return YES;
    // 根据key(URL地址)在磁盘中查找是否存在(key)对应的缓存
    return [self.imageCache diskImageExistsWithKey:key];
}

// 检查当前URL 本地磁盘中是否存在缓存
- (BOOL)diskImageExistsForURL:(NSURL *)url {
    // 根据url 取其内部的地址当做key
    NSString *key = [self cacheKeyForURL:url];
    // 根据key(URL地址)在磁盘中查找是否存在(key)对应的缓存
    return [self.imageCache diskImageExistsWithKey:key];
}


// 异步检查当前URL 在内存或本地磁盘中是否存在缓存 - 有回调
- (void)cachedImageExistsForURL:(NSURL *)url
                     completion:(SDWebImageCheckCacheCompletionBlock)completionBlock {
    // 根据url 取其内部的地址当做key
    NSString *key = [self cacheKeyForURL:url];
    
    // 根据key(URL地址)在内存中查找是否存在(key)对应的缓存
    BOOL isInMemoryCache = ([self.imageCache imageFromMemoryCacheForKey:key] != nil);
    
    // 在内存中
    if (isInMemoryCache) {
        // making sure we call the completion block on the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(YES);
            }
        });
        return;
    }
    
    // 不在内存中, 异步子线程查找key是否存在本地磁盘中
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        // the completion block of checkDiskCacheForImageWithKey:completion: is always called on the main queue, no need to further dispatch
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

// 异步检查当前URL 本地磁盘中是否存在缓存 - 有回调
- (void)diskImageExistsForURL:(NSURL *)url
                   completion:(SDWebImageCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        // the completion block of checkDiskCacheForImageWithKey:completion: is always called on the main queue, no need to further dispatch
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}

// 如果图片不在缓存中，根据指定的URL下载图片，否则使用缓存中的图片。
- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageOptions)options
                                        progress:(SDWebImageDownloaderProgressBlock)progressBlock
                                       completed:(SDWebImageCompletionWithFinishedBlock)completedBlock {
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[SDWebImagePrefetcher prefetchURLs] instead");

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, XCode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    __block SDWebImageCombinedOperation *operation = [SDWebImageCombinedOperation new];
    __weak SDWebImageCombinedOperation *weakOperation = operation;

    // 图片加载失败
    BOOL isFailedUrl = NO;
    @synchronized (self.failedURLs) {
        isFailedUrl = [self.failedURLs containsObject:url];
    }

    // 如果 url失效. 或者失败的url并且options != SDWebImageRetryFailed直接返回operation
    if (url.absoluteString.length == 0 || (!(options & SDWebImageRetryFailed) && isFailedUrl)) {
        dispatch_main_sync_safe(^{
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil];
            completedBlock(nil, error, SDImageCacheTypeNone, YES, url);
        });
        return operation;
    }

    // 添加到当前运行的opration数组中记录
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    // 根据url 取其内部的地址当做key
    NSString *key = [self cacheKeyForURL:url];

    // 储存当前发送的Operation
    operation.cacheOperation = [self.imageCache queryDiskCacheForKey:key done:^(UIImage *image, SDImageCacheType cacheType) {
        // 如果当前取消状态直接从当前请求操作里面移除
        if (operation.isCancelled) {
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }

            return;
        }

        if ((!image || options & SDWebImageRefreshCached) && (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url])) {
            // SDWebImageRefreshCached 将硬盘缓存交给系统自带的NSURLCache去处理，当同一个URL对应的图片经常更改时可以用这种策略
            if (image && options & SDWebImageRefreshCached) {
                dispatch_main_sync_safe(^{
                    // If image was found in the cache but SDWebImageRefreshCached is provided, notify about the cached image
                    // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
                    completedBlock(image, nil, cacheType, YES, url);
                });
            }

            // download if no image or requested to refresh anyway, and download allowed by delegate
            // 下载时图片模式
            SDWebImageDownloaderOptions downloaderOptions = 0;
            if (options & SDWebImageLowPriority) downloaderOptions |= SDWebImageDownloaderLowPriority;
            if (options & SDWebImageProgressiveDownload) downloaderOptions |= SDWebImageDownloaderProgressiveDownload;
            if (options & SDWebImageRefreshCached) downloaderOptions |= SDWebImageDownloaderUseNSURLCache;
            if (options & SDWebImageContinueInBackground) downloaderOptions |= SDWebImageDownloaderContinueInBackground;
            if (options & SDWebImageHandleCookies) downloaderOptions |= SDWebImageDownloaderHandleCookies;
            if (options & SDWebImageAllowInvalidSSLCertificates) downloaderOptions |= SDWebImageDownloaderAllowInvalidSSLCertificates;
            if (options & SDWebImageHighPriority) downloaderOptions |= SDWebImageDownloaderHighPriority;
            if (image && options & SDWebImageRefreshCached) {
                // force progressive off if image already cached but forced refreshing
                // 如果image已经被缓存但是设置了需要请求服务器刷新的选项，强制关闭渐进式选项
                downloaderOptions &= ~SDWebImageDownloaderProgressiveDownload;
                // ignore image read from NSURLCache if image if cached but force refreshing
                // 如果image已经被缓存但是设置了需要请求服务器刷新的选项，忽略从NSURLCache读取的image
                downloaderOptions |= SDWebImageDownloaderIgnoreCachedResponse;
            }
            
            // 加载图片去了
            id <SDWebImageOperation> subOperation = [self.imageDownloader downloadImageWithURL:url options:downloaderOptions progress:progressBlock completed:^(UIImage *downloadedImage, NSData *data, NSError *error, BOOL finished) {
                // 请求回调
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                // 当前view销毁/ 当前请求取消
                if (!strongOperation || strongOperation.isCancelled) {
                    // Do nothing if the operation was cancelled
                    // See #699 for more details
                    // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                }
                // 请求失败
                else if (error) {
                    dispatch_main_sync_safe(^{
                        if (strongOperation && !strongOperation.isCancelled) {
                            completedBlock(nil, error, SDImageCacheTypeNone, finished, url);
                        }
                    });

                    if (   error.code != NSURLErrorNotConnectedToInternet
                        && error.code != NSURLErrorCancelled
                        && error.code != NSURLErrorTimedOut
                        && error.code != NSURLErrorInternationalRoamingOff
                        && error.code != NSURLErrorDataNotAllowed
                        && error.code != NSURLErrorCannotFindHost
                        && error.code != NSURLErrorCannotConnectToHost) {
                        @synchronized (self.failedURLs) {
                            [self.failedURLs addObject:url];
                        }
                    }
                }
                // 成功
                else {
                    // SDWebImageRetryFailed 下载失败了会再次尝试下载
                    if ((options & SDWebImageRetryFailed)) {
                        @synchronized (self.failedURLs) {
                            // 成功移除
                            [self.failedURLs removeObject:url];
                        }
                    }
                    
                    // 缓存内存, 硬盘
                    BOOL cacheOnDisk = !(options & SDWebImageCacheMemoryOnly);

                    if (options & SDWebImageRefreshCached && image && !downloadedImage) {
                        // Image refresh hit the NSURLCache cache, do not call the completion block
                    }
                    // 形变图片
                    else if (downloadedImage && (!downloadedImage.images || (options & SDWebImageTransformAnimatedImage)) && [self.delegate respondsToSelector:@selector(imageManager:transformDownloadedImage:withURL:)]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            UIImage *transformedImage = [self.delegate imageManager:self transformDownloadedImage:downloadedImage withURL:url];

                            if (transformedImage && finished) {
                                BOOL imageWasTransformed = ![transformedImage isEqual:downloadedImage];
                                [self.imageCache storeImage:transformedImage recalculateFromImage:imageWasTransformed imageData:(imageWasTransformed ? nil : data) forKey:key toDisk:cacheOnDisk];
                            }

                            dispatch_main_sync_safe(^{
                                if (strongOperation && !strongOperation.isCancelled) {
                                    completedBlock(transformedImage, nil, SDImageCacheTypeNone, finished, url);
                                }
                            });
                        });
                    }
                    // 正常保存图片到缓存中
                    else {
                        if (downloadedImage && finished) {
                            [self.imageCache storeImage:downloadedImage recalculateFromImage:NO imageData:data forKey:key toDisk:cacheOnDisk];
                        }

                        dispatch_main_sync_safe(^{
                            if (strongOperation && !strongOperation.isCancelled) {
                                completedBlock(downloadedImage, nil, SDImageCacheTypeNone, finished, url);
                            }
                        });
                    }
                }

                if (finished) {
                    @synchronized (self.runningOperations) {
                        if (strongOperation) {
                            [self.runningOperations removeObject:strongOperation];
                        }
                    }
                }
            }];
            operation.cancelBlock = ^{
                [subOperation cancel];
                
                @synchronized (self.runningOperations) {
                    __strong __typeof(weakOperation) strongOperation = weakOperation;
                    if (strongOperation) {
                        [self.runningOperations removeObject:strongOperation];
                    }
                }
            };
        }
        // 内存中有图片
        else if (image) {
            dispatch_main_sync_safe(^{
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                if (strongOperation && !strongOperation.isCancelled) {
                    completedBlock(image, nil, cacheType, YES, url);
                }
            });
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }
        }
        // 其他情况
        else {
            // Image not in cache and download disallowed by delegate
            dispatch_main_sync_safe(^{
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                if (strongOperation && !weakOperation.isCancelled) {
                    completedBlock(nil, nil, SDImageCacheTypeNone, YES, url);
                }
            });
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }
        }
    }];

    // 返回当前 operation
    return operation;
}

// 根据RUL保存当前image
- (void)saveImageToCache:(UIImage *)image forURL:(NSURL *)url {
    if (image && url) {
        // 根据url 取其内部的地址当做key
        NSString *key = [self cacheKeyForURL:url];
        // 把图片保存到内存中并且保存在磁盘中
        [self.imageCache storeImage:image forKey:key toDisk:YES];
    }
}

// 取消全部当前的operations
- (void)cancelAll {
    @synchronized (self.runningOperations) {
        NSArray *copiedOperations = [self.runningOperations copy];
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

// 检查当前是否有opration请求
- (BOOL)isRunning {
    BOOL isRunning = NO;
    @synchronized(self.runningOperations) {
        isRunning = (self.runningOperations.count > 0);
    }
    return isRunning;
}

@end


@implementation SDWebImageCombinedOperation

// 取消当前操作
- (void)setCancelBlock:(SDWebImageNoParamsBlock)cancelBlock {
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        // 取消当前Operation请求
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        
        // TODO: this is a temporary fix to #809.
        // Until we can figure the exact cause of the crash, going with the ivar instead of the setter
//        self.cancelBlock = nil;
        _cancelBlock = nil;
    }
}

@end


@implementation SDWebImageManager (Deprecated)

// deprecated method, uses the non deprecated method
// adapter for the completion block
- (id <SDWebImageOperation>)downloadWithURL:(NSURL *)url options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletedWithFinishedBlock)completedBlock {
    return [self downloadImageWithURL:url
                              options:options
                             progress:progressBlock
                            completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                if (completedBlock) {
                                    completedBlock(image, error, cacheType, finished);
                                }
                            }];
}

@end
