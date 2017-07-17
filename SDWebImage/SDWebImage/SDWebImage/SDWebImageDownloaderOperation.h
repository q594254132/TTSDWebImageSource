/*
 * 我们的目的是下载一张图片，那么我们最核心的逻辑是什么呢？
 
 * 1. 初始化一个task
 * 2. 添加响应者
 * 3. 开启下载任务
 * 4. 处理下载过程和结束后的事情
 */

#import <Foundation/Foundation.h>
#import "SDWebImageDownloader.h"
#import "SDWebImageOperation.h"

extern NSString *const SDWebImageDownloadStartNotification;
extern NSString *const SDWebImageDownloadReceiveResponseNotification;
extern NSString *const SDWebImageDownloadStopNotification;
extern NSString *const SDWebImageDownloadFinishNotification;

@interface SDWebImageDownloaderOperation : NSOperation <SDWebImageOperation, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

/**
 * The request used by the operation's task.
 * 下载时用于网络请求的request
 */
@property (strong, nonatomic, readonly) NSURLRequest *request;

/**
 * The operation's task
 */
@property (strong, nonatomic, readonly) NSURLSessionTask *dataTask;


/** 图片下载完成是否需要解压 默认YES
 */
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 *  Was used to determine whether the URL connection should consult the credential storage for authenticating the connection.
 *  @deprecated Not used for a couple of versions
 * :URLConnection是否需要咨询凭据仓库来对连接进行授权,默认YES, 已经废弃
 */
@property (nonatomic, assign) BOOL shouldUseCredentialStorage __deprecated_msg("Property deprecated. Does nothing. Kept only for backwards compatibility");

/**
 * web服务要求客户端进行挑战,用NSURLConnectionDelegate提供的方法接收凭证,最终会生成一个凭证,也是NSURLCredential的实例 credential
 */
@property (nonatomic, strong) NSURLCredential *credential;

/**
 * The SDWebImageDownloaderOptions for the receiver.
 * SDWebImageDownloader.h里面定义的,一些下载相关的选项
 */
@property (assign, nonatomic, readonly) SDWebImageDownloaderOptions options;

/**
 * The expected size of data.
 * 预期的文件大小
 */
@property (assign, nonatomic) NSInteger expectedSize;

/**
 * The response returned by the operation's connection.
 * connection对象进行网络访问,接收到的response
 */
@property (strong, nonatomic) NSURLResponse *response;

/**
 *  Initializes a `SDWebImageDownloaderOperation` object
 *
 *  @see SDWebImageDownloaderOperation
 *
 *  @param request        the URL request
 *  @param session        the URL session in which this operation will run
 *  @param options        downloader options
 *  @param progressBlock  the block executed when a new chunk of data arrives. 
 *                        @note the progress block is executed on a background queue
 *  @param completedBlock the block executed when the download is done. 
 *                        @note the completed block is executed on the main queue for success. If errors are found, there is a chance the block will be executed on a background queue
 *  @param cancelBlock    the block executed if the download (operation) is cancelled
 *
 *  @return the initialized instance
 * 用默认的属性值初始化一个SDWebImageDownloaderOperation对象
 */
- (id)initWithRequest:(NSURLRequest *)request
            inSession:(NSURLSession *)session
              options:(SDWebImageDownloaderOptions)options
             progress:(SDWebImageDownloaderProgressBlock)progressBlock
            completed:(SDWebImageDownloaderCompletedBlock)completedBlock
            cancelled:(SDWebImageNoParamsBlock)cancelBlock;

/**
 *  Initializes a `SDWebImageDownloaderOperation` object
 *
 *  @see SDWebImageDownloaderOperation
 *
 *  @param request        the URL request
 *  @param options        downloader options
 *  @param progressBlock  the block executed when a new chunk of data arrives.
 *                        @note the progress block is executed on a background queue
 *  @param completedBlock the block executed when the download is done.
 *                        @note the completed block is executed on the main queue for success. If errors are found, there is a chance the block will be executed on a background queue
 *  @param cancelBlock    the block executed if the download (operation) is cancelled
 *
 *  @return the initialized instance. The operation will run in a separate session created for this operation
 * 用默认的属性值初始化一个SDWebImageDownloaderOperation对象[废弃]
 */
- (id)initWithRequest:(NSURLRequest *)request
              options:(SDWebImageDownloaderOptions)options
             progress:(SDWebImageDownloaderProgressBlock)progressBlock
            completed:(SDWebImageDownloaderCompletedBlock)completedBlock
            cancelled:(SDWebImageNoParamsBlock)cancelBlock
__deprecated_msg("Method deprecated. Use `initWithRequest:inSession:options:progress:completed:cancelled`");

@end
