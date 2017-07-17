/*
 **
 *** 存在的坑:
 **
 * 坑1: 在cell 中调用sd_setAnimationImagesWithURLs 加载一组图片有问题: 在cell 重用的时候图片组会叠加把不同的图片叠加进来, 内存越来越大, 
 * 解决办法: 在sd_setAnimationImagesWithURLs之前增加 cell.imgView.animationImages = nil;
 *
 * 坑2: 点击会发现图片没了
 * 原因: cell 有多种状态, cell.imgView.animationImages 在其他状态不兼容
 * 解决办法: 设置cell的选中状态 self.selectionStyle = UITableViewCellSelectionStyleNone
 *
 * 坑3: sd_setAnimationImagesWithURLs 设置菊花没有效果
 * 原因: 内部是没有添加菊花控件的代码, 所以不能设置菊花控件
 *
 */

#import "UIImageView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"

// 用其地址作为当前对象新关联的属性名称, 存放当前对象发送出去的url, 存放在静态区的一个变量, 并且生命周期跟app同步, 只有一个存储地址
static char imageURLKey;
// 用其地址作为当前对象新关联的属性名称, 存放当前对象显示的菊花控件 存放在静态区的一个变量, 并且生命周期跟app同步, 只有一个存储地址
static char TAG_ACTIVITY_INDICATOR;
// 用其地址作为当前对象新关联的属性名称, 存放当前对象显示的菊花样式, 存放在静态区的一个变量, 并且生命周期跟app同步, 只有一个存储地址
static char TAG_ACTIVITY_STYLE;
// 用其地址作为当前对象新关联的属性名称, 存放当前对象是否需要菊花, 存放在静态区的一个变量, 并且生命周期跟app同步, 只有一个存储地址
static char TAG_ACTIVITY_SHOW;

@implementation UIImageView (WebCache)

// 获取当前imageURL. imageURL 是在加载的时候利用runtime保存到当前对象里的url -- 私有
- (void)sd_setImageWithURL:(NSURL *)url {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

// 根据url 设置 imageView 的image, 在加载的过程中先显示placeholder
- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

// 根据url 设置 imageView 的image,但是加载过程中根据options模式去加载, 在加载的过程中先显示placeholder
- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

// 根据url 设置 imageView 的image, 成功最后有个回调
- (void)sd_setImageWithURL:(NSURL *)url completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

// 根据url 设置 imageView 的image, 在加载的过程中先显示placeholder, 成功之后有回调
- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

// 根据url 设置 imageView 的image,但是加载过程中根据options模式去加载, 在加载的过程中先显示placeholder, 成功之后有回调
- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

/**
 * 根据url 设置 imageView 的image,但是加载过程中根据options模式去加载, 在加载的过程中先显示placeholder, 图片加载中有图片加载进度, 成功后有回调
 * 注意: 上面的方法都是围绕这个方法的一些扩展. 最终还是调用此方法
 */
- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletionBlock)completedBlock {
    // 取消移除之前的operation操作, 当TableView的cell包含的UIImageView被重用的时候首先执行这一行代码,保证这个ImageView的下载和缓存组合操作都被取消
    [self sd_cancelCurrentImageLoad];
    // 关联该view对应的图片URL, 当做属性存储到内部
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 延迟 placeholder 的加载
    if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            self.image = placeholder;
        });
    }
    
    // URL 有值
    if (url) {
        // check if activityView is enabled or not
        // 是否显示菊花控件
        if ([self showActivityIndicatorView]) {
            // 添加菊花控件
            [self addActivityIndicator];
        }

        __weak __typeof(self)wself = self;
        // 创建发送请求的oprations由SDWebImageManager负责获取图片
        id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadImageWithURL:url options:options progress:progressBlock completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            [wself removeActivityIndicator];
            if (!wself) return;
            dispatch_main_sync_safe(^{
                if (!wself) return;
                // 默认情况下是等image完全从网络端下载完后，就会直接将结果设置到UIImageView。但是有些人想在获取到图片后，对图片做一些处理，比如使用filter去渲染图片或者给图片加个cross-fade animation(淡出动画)显示出来。那你就设置这个选项。然后得手动去处理图片下载完成后的事情。最终也会走这个
                if (image && (options & SDWebImageAvoidAutoSetImage) && completedBlock)
                {
                    completedBlock(image, error, cacheType, url);
                    return;
                }
                else if (image) {
                    wself.image = image;
                    [wself setNeedsLayout];
                } else {
                    // 加载图片失败
                    if ((options & SDWebImageDelayPlaceholder)) {
                        wself.image = placeholder;
                        [wself setNeedsLayout];
                    }
                }
                // 成功并且有回调, 最终也会走这个方法
                if (completedBlock && finished) {
                    completedBlock(image, error, cacheType, url);
                }
            });
        }];
        [self sd_setImageLoadOperation:operation forKey:@"UIImageViewImageLoad"];
    } else { // url = nil
        // 回到主线程更新UI
        dispatch_main_async_safe(^{
            // 移除菊花控件
            [self removeActivityIndicator];
            // 打印提示
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                // 回调
                completedBlock(nil, error, SDImageCacheTypeNone, url);
            }
        });
    }
}
/**
 * 它的思路是先从内存和本地磁盘取得上次加载的图片作为占位图，然后再次进行一次图片加载设置
 */
- (void)sd_setImageWithPreviousCachedImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletionBlock)completedBlock {
    // 根据url 获取到url 中的字符串key(一般就是路径)
    NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:url];
    // 根据key获取磁盘或者内存中的图片
    UIImage *lastPreviousCachedImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:key];
    // 把已经获取到的图片作为占位图去加载最新图片
    [self sd_setImageWithURL:url placeholderImage:lastPreviousCachedImage ?: placeholder options:options progress:progressBlock completed:completedBlock];
}

// 获取当前imageURL. imageURL 是在加载的时候利用runtime保存到当前对象里的url
- (NSURL *)sd_imageURL {
    return objc_getAssociatedObject(self, &imageURLKey);
}

// 加载一组图片, 并且循环这个一组动画展现
- (void)sd_setAnimationImagesWithURLs:(NSArray *)arrayOfURLs {
    // 取消之前的加载项
    [self sd_cancelCurrentAnimationImagesLoad];
    __weak __typeof(self)wself = self;

    NSMutableArray *operationsArray = [[NSMutableArray alloc] init];

    for (NSURL *logoImageURL in arrayOfURLs) {
        // 创建发送请求的oprations
        id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadImageWithURL:logoImageURL options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            if (!wself) return;
            // 主线程UI赋值
            dispatch_main_sync_safe(^{
                __strong UIImageView *sself = wself;
                // 停止当前动画
                [sself stopAnimating];
                if (sself && image) {
                    // 获取当前正在动画的图片, 默认animationImages 是nil
                    NSMutableArray *currentImages = [[sself animationImages] mutableCopy];
                    // 没有则创建
                    if (!currentImages) {
                        currentImages = [[NSMutableArray alloc] init];
                    }
                    // 存储image
                    [currentImages addObject:image];
                    sself.animationImages = currentImages;
                    // 更新UI
                    [sself setNeedsLayout];
                }
                // 开始动画
                [sself startAnimating];
            });
        }];
        // 存储所有的opration
        [operationsArray addObject:operation];
    }

    // 把当前的operationsArray 存到当前对象内部根据key: UIImageViewAnimationImages
    [self sd_setImageLoadOperation:[NSArray arrayWithArray:operationsArray] forKey:@"UIImageViewAnimationImages"];
}

// 根据key值UIImageViewImageLoad取消当前对象对应的加载opration --> 单一图片
- (void)sd_cancelCurrentImageLoad {
    [self sd_cancelImageLoadOperationWithKey:@"UIImageViewImageLoad"];
}
// 根据key值UIImageViewAnimationImages取消当前对象对应的加载opration --> 动画组图片
- (void)sd_cancelCurrentAnimationImagesLoad {
    [self sd_cancelImageLoadOperationWithKey:@"UIImageViewAnimationImages"];
}


#pragma mark -
// 获取菊花控件 -- 私有
- (UIActivityIndicatorView *)activityIndicator {
    return (UIActivityIndicatorView *)objc_getAssociatedObject(self, &TAG_ACTIVITY_INDICATOR);
}

// 设置菊花控件 -- 私有
- (void)setActivityIndicator:(UIActivityIndicatorView *)activityIndicator {
    // 存储菊花控件到当前对象中
    objc_setAssociatedObject(self, &TAG_ACTIVITY_INDICATOR, activityIndicator, OBJC_ASSOCIATION_RETAIN);
}

// 是否显示菊花控件
- (void)setShowActivityIndicatorView:(BOOL)show{
    // 把是否存储菊花存储到当前对象中
    objc_setAssociatedObject(self, &TAG_ACTIVITY_SHOW, [NSNumber numberWithBool:show], OBJC_ASSOCIATION_RETAIN);
}

// 获取菊花控件状态 -- 私有
- (BOOL)showActivityIndicatorView{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_SHOW) boolValue];
}

// 获取菊花控件样式
- (void)setIndicatorStyle:(UIActivityIndicatorViewStyle)style{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_STYLE, [NSNumber numberWithInt:style], OBJC_ASSOCIATION_RETAIN);
}

// 获取菊花控件样式 -- 私有
- (int)getIndicatorStyle{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_STYLE) intValue];
}

// 添加菊花控件
- (void)addActivityIndicator {
    // 如果没有设置过菊花控件
    if (!self.activityIndicator) {
        // 设置菊花控件, 设置菊花的样式
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:[self getIndicatorStyle]];
        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;

        // 回到主线程更新UI布局
        dispatch_main_async_safe(^{
            [self addSubview:self.activityIndicator];

            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0
                                                              constant:0.0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0
                                                              constant:0.0]];
        });
    }

    // 回到主线程, 让菊花控件转动
    dispatch_main_async_safe(^{
        [self.activityIndicator startAnimating];
    });

}

// 移除菊花控件
- (void)removeActivityIndicator {
    if (self.activityIndicator) {
        [self.activityIndicator removeFromSuperview];
        self.activityIndicator = nil;
    }
}

@end

/**
 * 过期方法
 */
@implementation UIImageView (WebCacheDeprecated)

// 获取当前imageURL. imageURL 是在加载的时候利用runtime保存到当前对象里的url
- (NSURL *)imageURL {
    return [self sd_imageURL];
}

// 根据url 设置 imageView 的image
- (void)setImageWithURL:(NSURL *)url {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

// 根据url 设置 imageView 的image, 在加载的过程中先显示placeholder
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

// 根据url 设置 imageView 的image,但是加载过程中根据options模式去加载, 在加载的过程中先显示placeholder
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

// 根据url 设置 imageView 的image, 成功最后有个回调
- (void)setImageWithURL:(NSURL *)url completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

// 根据url 设置 imageView 的image, 在加载的过程中先显示placeholder, 成功之后有回调
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

// 根据url 设置 imageView 的image,但是加载过程中根据options模式去加载, 在加载的过程中先显示placeholder, 成功之后有回调
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

// 根据url 设置 imageView 的image,但是加载过程中根据options模式去加载, 在加载的过程中先显示placeholder, 图片加载中有图片加载进度, 成功后有回调
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:progressBlock completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

// 它的思路是先从内存和本地磁盘取得上次加载的图片作为占位图，然后再次进行一次图片加载设置
- (void)sd_setImageWithPreviousCachedImageWithURL:(NSURL *)url andPlaceholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithPreviousCachedImageWithURL:url placeholderImage:placeholder options:options progress:progressBlock completed:completedBlock];
}

- (void)cancelCurrentArrayLoad {
    [self sd_cancelCurrentAnimationImagesLoad];
}

- (void)cancelCurrentImageLoad {
    [self sd_cancelCurrentImageLoad];
}

// 加载一组图片, 并且循环这个一组动画展现
- (void)setAnimationImagesWithURLs:(NSArray *)arrayOfURLs {
    [self sd_setAnimationImagesWithURLs:arrayOfURLs];
}

@end
