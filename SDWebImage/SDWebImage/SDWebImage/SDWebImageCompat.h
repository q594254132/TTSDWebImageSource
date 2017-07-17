/** SD的配置文件, 兼容Apple的其他设备
 */

#import <TargetConditionals.h>

/** __OBJC_GC__
 * SDWebImage不支持垃圾回收机制，垃圾回收(Gargage-collection)是Objective-c提供的一种自动内存回收机制。在iPad/iPhone环境中不支持垃圾回收功能。
 * 当启动这个功能后，所有的retain,autorelease,release和dealloc方法都将被系统忽略。
 */
#ifdef __OBJC_GC__
#error SDWebImage does not support Objective-C Garbage Collection
#endif

/** 版本判断 */
#if __IPHONE_OS_VERSION_MIN_REQUIRED != 20000 && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
#error SDWebImage doesn't support Deployment Target version < 5.0
#endif

/** TARGET_OS_IPHONE
 * 该指令主要用于判断当前平台是不是MAC，单纯使用TARGET_OS_IPHONE是不靠谱的。这样判断的缺点是，当Apple出现新的平台时，判断条件要修改。
 
 * TARGET_OS_IPHONE
 * TARGET_OS_IOS
 * TARGET_OS_TV
 * TARGET_OS_WATCH
 */
#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#ifndef UIImage
#define UIImage NSImage
#endif
#ifndef UIImageView
#define UIImageView NSImageView
#endif
#else

#import <UIKit/UIKit.h>

#endif

/** 基础设置 */
#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#ifndef NS_OPTIONS
#define NS_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#if OS_OBJECT_USE_OBJC
    #undef SDDispatchQueueRelease
    #undef SDDispatchQueueSetterSementics
    #define SDDispatchQueueRelease(q)
    #define SDDispatchQueueSetterSementics strong
#else
#undef SDDispatchQueueRelease
#undef SDDispatchQueueSetterSementics
#define SDDispatchQueueRelease(q) (dispatch_release(q))
#define SDDispatchQueueSetterSementics assign
#endif

/** 接口 */
extern UIImage *SDScaledImageForKey(NSString *key, UIImage *image);

typedef void(^SDWebImageNoParamsBlock)();

extern NSString *const SDWebImageErrorDomain;

/** 线程 
 * 第一，我们可以像这样在定义宏的时候使用换行，但需要添加 \ 操作符
 * 第二，如果当前线程已经是主线程了，那么在调用
 *    dispatch_async(dispatch_get_main_queue(), block)有可能会出现crash
 * 第三，如果当前线程是主线程，直接调用，如果不是，调用
 *    dispatch_async(dispatch_get_main_queue(), block)
 */
#define dispatch_main_sync_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_sync(dispatch_get_main_queue(), block);\
    }

#define dispatch_main_async_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }
