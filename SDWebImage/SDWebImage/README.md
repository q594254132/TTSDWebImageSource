Web Image
=========
[![Build Status](http://img.shields.io/travis/rs/SDWebImage/master.svg?style=flat)](https://travis-ci.org/rs/SDWebImage)
[![Pod Version](http://img.shields.io/cocoapods/v/SDWebImage.svg?style=flat)](http://cocoadocs.org/docsets/SDWebImage/)
[![Pod Platform](http://img.shields.io/cocoapods/p/SDWebImage.svg?style=flat)](http://cocoadocs.org/docsets/SDWebImage/)
[![Pod License](http://img.shields.io/cocoapods/l/SDWebImage.svg?style=flat)](https://www.apache.org/licenses/LICENSE-2.0.html)
[![Dependency Status](https://www.versioneye.com/objective-c/sdwebimage/3.3/badge.svg?style=flat)](https://www.versioneye.com/objective-c/sdwebimage/3.3)
[![Reference Status](https://www.versioneye.com/objective-c/sdwebimage/reference_badge.svg?style=flat)](https://www.versioneye.com/objective-c/sdwebimage/references)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/rs/SDWebImage)

This library provides a category for UIImageView with support for remote images coming from the web.
这个库提供了一个类别UIImageView支持远程图片来自网络。

It provides:

- An `UIImageView` category adding web image and cache management to the Cocoa Touch framework
- UIImageView 类别添加web图像和缓存管理可可触摸框架
- An asynchronous image downloader
- 异步图片下载器
- An asynchronous memory + disk image caching with automatic cache expiration handling
- 异步内存+磁盘映像缓存自动缓存过期处理
- Animated GIF support
- gif动画支持
- WebP format support
- web格式支持
- A background image decompression
- 一个背景图像解压缩
- A guarantee that the same URL won't be downloaded several times
- 保证相同的URL不会下载多次
- A guarantee that bogus URLs won't be retried again and again
- 保证不正确的url多次重试
- A guarantee that main thread will never be blocked
- 保证主线程不会被阻塞
- Performances!
- Use GCD and ARC
- 使用GCD 和ARC
- Arm64 support
- 64 位支持


NOTE: Version 3.8 of SDWebImage requires iOS 7 or later (because of NSURLSession).
注意: SDWebimage3.8版本必须ios7或者更高版本
Versions 3.7 to 3.0 requires iOS 5.1.1. If you need iOS < 5.0 support, please use the last [2.0 version](https://github.com/rs/SDWebImage/tree/2.0-compat).
3.0-3.7版本必须ios5.1.1 如果你需要ios5.0以下的支持, 请使用上个2.0版本

[How is SDWebImage better than X?](https://github.com/rs/SDWebImage/wiki/How-is-SDWebImage-better-than-X%3F)
SDWebImage如何好于X?
下面是链接中翻译的大致内容: 
iOS 5.0以来,NSURLCache处理磁盘缓存,在平原NSURLRequest SDWebImage的优势是什么?

iOS NSURLCache做内存和磁盘缓存(因为iOS 5)的原始HTTP响应。每次缓存,缓存应用程序将不得不变换原始数据到一个用户界面图像。这涉及到广泛的操作,比如数据解析(HTTP数据编码),内存复制等。
另一方面,SDWebImage在内存中缓存用户界面图像表示和存储原始压缩(但解码)图像文件在磁盘上。使用NSCache界面图像按原样存储在内存中,所以没有复制,尽快和内存被释放你的应用程序或系统的需求。
此外,图像压缩,通常发生在主线程你第一次使用用户界面图像在一个由SDWebImageDecoder UIImageView被迫在一个后台线程。
最后但并非最不重要,SDWebImage将完全绕过复杂,通常配置HTTP缓存控制谈判。这大大加速缓存查找。

自从AFNetworking为UIImageView提供类似的功能,SDWebImage还有用吗?

可以说没有。AFNetworking利用基础URL加载系统使用NSURLCache缓存,以及一个可配置的内存缓存UIImageView UIButton,它使用默认NSCache。缓存行为可以进一步的缓存策略中指定相应的NSURLRequest。其他SDWebImage特性,比如背景压缩图像数据也由AFNetworking提供。
如果你已经使用AFNetworking,只想要一个简单的异步加载图像类别,内置UIKit扩展可能会满足您的需要。

Who Uses It
谁使用它
----------

Find out [who uses SDWebImage](https://github.com/rs/SDWebImage/wiki/Who-Uses-SDWebImage) and add your app to the list.
找出谁在使用SDWebImage
How To Use
----------

API documentation is available at [CocoaDocs - SDWebImage](http://cocoadocs.org/docsets/SDWebImage/)
API文档
### Using UIImageView+WebCache category with UITableView
### 使用 UIImageView+WebCache 分类 在tableView
Just #import the UIImageView+WebCache.h header, and call the sd_setImageWithURL:placeholderImage: method 
知识导入 UIImageView+WebCache.h 头文件, 并且 调用 sd_setImageWithURL:placeholderImage: 方法
from the tableView:cellForRowAtIndexPath: UITableViewDataSource method. 
在 tableView:cellForRowAtIndexPath: 数据源方法. 
Everything will be handled for you, from async downloads to caching management.
一切事情都会为你处理 从异步加载缓存管理
例子: 
```objective-c
#import <SDWebImage/UIImageView+WebCache.h>

...

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
static NSString *MyIdentifier = @"MyIdentifier";

UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
if (cell == nil) {
cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
reuseIdentifier:MyIdentifier] autorelease];
}

// Here we use the new provided sd_setImageWithURL: method to load the web image
[cell.imageView sd_setImageWithURL:[NSURL URLWithString:@"http://www.domain.com/path/to/image.jpg"]
placeholderImage:[UIImage imageNamed:@"placeholder.png"]];

cell.textLabel.text = @"My Text";
return cell;
}
```

### Using blocks

With blocks, you can be notified about the image download progress and whenever the image retrieval
has completed with success or not:
块,你可以通知图像下载进度,当图像的检索已经完成与成功或失败

```objective-c
// Here we use the new provided sd_setImageWithURL: method to load the web image
[cell.imageView sd_setImageWithURL:[NSURL URLWithString:@"http://www.domain.com/path/to/image.jpg"]
                      placeholderImage:[UIImage imageNamed:@"placeholder.png"]
                             completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
                                ... completion code here ...
                             }];
```

Note: neither your success nor failure block will be call if your image request is canceled before completion.
注意:无论是成功还是失败block将调用,如果你图像请求取消之前完成
### Using SDWebImageManager
### 使用 SDWebImageManager
The SDWebImageManager is the class behind the UIImageView+WebCache category. 
这个 SDWebImageManager 是针对 UIImageView+WebCache分类
It ties the asynchronous downloader with the image cache store. 
关系的异步下载图像缓存存储。
You can use this class directly to benefit from web image downloading with caching in another context than a UIView (ie: with Cocoa).
可以使用这个类直接受益于网络图片下载,在另一个上下文缓存UIView。

Here is a simple example of how to use SDWebImageManager:
这里是一个简单的例子如何使用 SDWebImageManager

```objective-c
SDWebImageManager *manager = [SDWebImageManager sharedManager];
[manager downloadImageWithURL:imageURL
                      options:0
                     progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                         // progression tracking code
                     }
                     completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                         if (image) {
                             // do something with image
                         }
                     }];
```

### Using Asynchronous Image Downloader Independently
### 使用异步图片单独加载
It's also possible to use the async image downloader independently:
也可以使用异步图片单独下载:

```objective-c
SDWebImageDownloader *downloader = [SDWebImageDownloader sharedDownloader];
[downloader downloadImageWithURL:imageURL
                         options:0
                        progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                            // progression tracking code
                        }
                       completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                            if (image && finished) {
                                // do something with image
                            }
                        }];
```

### Using Asynchronous Image Caching Independently
### 使用异步图片单独缓存

It is also possible to use the async based image cache store independently.
也可以单独使用基于异步的图像缓存存储
SDImageCache maintains a memory cache and an optional disk cache. 
SDImageCache维护一个内存缓存和一个可选的磁盘缓存。
Disk cache write operations are performed asynchronous so it doesn't add unnecessary latency to the UI.
磁盘高速缓存异步执行写操作,所以它不添加不必要的延迟到UI

The SDImageCache class provides a singleton instance for convenience but you can create your own
instance if you want to create separated cache namespace.
SDImageCache类提供了一个单例实例为了方便但是你可以创建你自己的如果你想创建实例分离缓存名称空间。

To lookup the cache, you use the `queryDiskCacheForKey:done:` method. If the method returns nil, 
查找缓存, 你使用 queryDiskCacheForKey:done: 方法, 如果方法返回nil,
it means the cache doesn't currently own the image. You are thus responsible for generating and caching it. 
它意味当前图片的缓存不存在, 因此负责生成和缓存
The cache key is an application unique identifier for the image to cache. It is generally the absolute URL of the image. 
缓存关键是一个应用缓存图片唯一标示符, 通常使用图片的绝对url路径


```objective-c
SDImageCache *imageCache = [[SDImageCache alloc] initWithNamespace:@"myNamespace"];
[imageCache queryDiskCacheForKey:myCacheKey done:^(UIImage *image) {
    // image is not nil if image was found
}];
```

By default SDImageCache will lookup the disk cache if an image can't be found in the memory cache.
You can prevent this from happening by calling the alternative method `imageFromMemoryCacheForKey:`.

默认情况下SDImageCache将查找磁盘缓存如果图像不能被发现在内存缓存中。您可以通过调用替代方法来避免这个问题的发生“imageFromMemoryCacheForKey:”。

To store an image into the cache, you use the storeImage:forKey: method:
一个图像存储到缓存中,你使用storeImage:forKey:方法:

```objective-c
[[SDImageCache sharedImageCache] storeImage:myImage forKey:myCacheKey];
```

By default, the image will be stored in memory cache as well as on disk cache (asynchronously). If
you want only the memory cache, use the alternative method storeImage:forKey:toDisk: with a negative
third argument.
默认情况下,图像将被存储在内存中缓存以及磁盘缓存(异步)。如果你想要的只有内存缓存,使用替代方法storeImage:forKey:toDisk:否定第三个参数。

### Using cache key filter
### 使用缓存键过滤器
Sometime, you may not want to use the image URL as cache key because part of the URL is dynamic
有时, 您可能不希望使用图像URL缓存键,因为URL的一部分是动态的
SDWebImageManager provides a way to set a cache key filter that takes the NSURL as input, and output a cache key NSString.
SDWebImageManager过滤器提供了一种方法来设置缓存键需要NSURL作为输入,输出缓存键NSString。

The following example sets a filter in the application delegate that will remove any query-string from
the URL before to use it as a cache key:
下面的示例应用程序中设置一个过滤器委托,将删除任何查询字符串URL之前使用它作为一个缓存键:

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    SDWebImageManager.sharedManager.cacheKeyFilter = ^(NSURL *url) {
        url = [[NSURL alloc] initWithScheme:url.scheme host:url.host path:url.path];
        return [url absoluteString];
    };

    // Your app init code...
    return YES;
}
```


Common Problems
---------------

### Using dynamic image size with UITableViewCell
### 使用动态与UITableViewCell图像大小

UITableView determines the size of the image by the first image set for a cell. If your remote images
don't have the same size as your placeholder image, you may experience strange anamorphic scaling issue.
The following article gives a way to workaround this issue:
UITableView决定图像第一图像的大小为一个细胞。如果你的远程图像没有相同的尺寸作为图像占位符,您可能会遇到奇怪的变形的可伸缩性问题。本文给出了一个方法来解决这个问题:

[http://www.wrichards.com/blog/2011/11/sdwebimage-fixed-width-cell-images/](http://www.wrichards.com/blog/2011/11/sdwebimage-fixed-width-cell-images/)


### Handle image refresh
### 处理图像刷新

SDWebImage does very aggressive caching by default.
SDWebImage 默认很暴力缓存
It ignores all kind of caching control header returned by the HTTP server and cache the returned images with no time restriction. 
它忽略了所有的缓存控制头返回的HTTP服务器和缓存返回的图像没有时间限制。
It implies your images URLs are static URLs pointing to images that never change. If the pointed image happen to change, some parts of the URL should change accordingly.
这意味着你的图像url静态url指向图片永远不会改变。如果指出图像发生变化,相应的URL应该改变的某些部分。

If you don't control the image server you're using, you may not be able to change the URL when its content is updated. 
如果你不控制服务器使用的图片,你可能无法改变URL时其内容更新。
This is the case for Facebook avatar URLs for instance. 
这是Facebook的理由例如阿凡达的url
In such case, you may use the `SDWebImageRefreshCached` flag. This will slightly degrade the performance but will respect the HTTP caching control headers:
在这种情况下,你可以使用“SDWebImageRefreshCached”标志。这将略降低性能,但会尊重HTTP缓存控制标题:

``` objective-c
[imageView sd_setImageWithURL:[NSURL URLWithString:@"https://graph.facebook.com/olivier.poitrey/picture"]
                 placeholderImage:[UIImage imageNamed:@"avatar-placeholder.png"]
                          options:SDWebImageRefreshCached];
```

### Add a progress indicator
### 添加一个进度
See this category: https://github.com/JJSaccolo/UIActivityIndicator-for-SDWebImage

Installation
------------

There are three ways to use SDWebImage in your project:
- using CocoaPods
- copying all the files into your project
- importing the project as a static library

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries in your projects. See the [Get Started](http://cocoapods.org/#get_started) section for more details.

#### Podfile
```
platform :ios, '7.0'
pod 'SDWebImage', '~>3.8'
```

If you are using Swift, be sure to add `use_frameworks!` and set your target to iOS 8+:
```
platform :ios, '8.0'
use_frameworks!
```

#### Subspecs

There are 3 subspecs available now: `Core`, `MapKit` and `WebP` (this means you can install only some of the SDWebImage modules. By default, you get just `Core`, so if you need `WebP`, you need to specify it). 

Podfile example:
```
pod 'SDWebImage/WebP'
```

### Installation with Carthage (iOS 8+)

[Carthage](https://github.com/Carthage/Carthage) is a lightweight dependency manager for Swift and Objective-C. It leverages CocoaTouch modules and is less invasive than CocoaPods.

To install with carthage, follow the instruction on [Carthage](https://github.com/Carthage/Carthage)

#### Cartfile
```
github "rs/SDWebImage"
```

#### Usage
Swift

If you installed using CocoaPods:
```
import SDWebImage
```

If you installed manually:
```
import WebImage
```

Objective-C

```
@import WebImage;
```

### Installation by cloning the repository

In order to gain access to all the files from the repository, you should clone it.
```
git clone --recursive https://github.com/rs/SDWebImage.git
```

### Add the SDWebImage project to your project

- Download and unzip the last version of the framework from the [download page](https://github.com/rs/SDWebImage/releases)
- Right-click on the project navigator and select "Add Files to "Your Project":
- In the dialog, select SDWebImage.framework:
- Check the "Copy items into destination group's folder (if needed)" checkbox

### Add dependencies

- In you application project app’s target settings, find the "Build Phases" section and open the "Link Binary With Libraries" block:
- Click the "+" button again and select the "ImageIO.framework", this is needed by the progressive download feature:

### Add Linker Flag

Open the "Build Settings" tab, in the "Linking" section, locate the "Other Linker Flags" setting and add the "-ObjC" flag:

![Other Linker Flags](http://dl.dropbox.com/u/123346/SDWebImage/10_other_linker_flags.jpg)

Alternatively, if this causes compilation problems with frameworks that extend optional libraries, such as Parse,  RestKit or opencv2, instead of the -ObjC flag use:
```
-force_load SDWebImage.framework/Versions/Current/SDWebImage
```

If you're using Cocoa Pods and have any frameworks that extend optional libraries, such as Parsen RestKit or opencv2, instead of the -ObjC flag use:
```
-force_load $(TARGET_BUILD_DIR)/libPods.a
```
and this:
```
$(inherited)
```

### Import headers in your source files
### 导入头在你的源文件
In the source files where you need to use the library, import the header file:

```objective-c
#import <SDWebImage/UIImageView+WebCache.h>
```

### Build Project

At this point your workspace should build without error. If you are having problem, post to the Issue and the
community can help you solve it.

Future Enhancements
-------------------

- LRU memory cache cleanup instead of reset on memory warning

## Licenses

All source code is licensed under the [MIT License](https://raw.github.com/rs/SDWebImage/master/LICENSE).
