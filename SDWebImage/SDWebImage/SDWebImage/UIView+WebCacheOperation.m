/*
 **
 *** 可能有的疑问?
 **
 * 疑问1: 如果这个地址唯一那么N个对象新增的属性是否保存到同一个地址上, 简单点说这个唯一地址指向的是否是最后一次赋值?
 * 答 : 不是, 因为self是不同的, 它只是关联一个变量的地址作为自己的属性名称而已, 具体地址系统分配的, 具体地址指向的值跟属性名2马事.
 *   A -> &loadOperationKey = operations
 *   B -> &loadOperationKey = operations2
 *
 * 疑问2: 为什么用NSMutableDictionary 而不用NSMutableArray ?
 * 答: 因为一个对象内部可能有多个状态下的图片, 比如按钮, 按钮有selected, highlight, normal, disabled状态等,这样就不能用数组, 用NSMutableArray就会把所有请求都取消, 只能用NSMutableDictionary
 **
 *** 存在的坑:
 **
 * 坑1: 如果一个对象先后调用如下代码, 就会出现问题......
        [self.imageView sd_setAnimationImagesWithURLs:images];
        [self.imageView sd_setImageWithURL:image];
 * 原因: 在调用 sd_cancelCurrentAnimationImagesLoad/ sd_cancelCurrentImageLoad 是没有考虑下一次加载 sd_cancelCurrentImageLoad/ sd_cancelCurrentAnimationImagesLoad, 就是没有考虑另一种方式
 * 解决办法: 在下次调用时调用一次 sd_cancelCurrentAnimationImagesLoad/ sd_cancelCurrentImageLoad
        [self.imageView sd_setAnimationImagesWithURLs:images];
        [self.imageView sd_cancelCurrentAnimationImagesLoad]; // sd_cancelCurrentImageLoad
        [self.imageView sd_setImageWithURL:image];
 */

#import "UIView+WebCacheOperation.h"
#import "objc/runtime.h"

// 用其地址作为当前对象新关联的属性名称, 存放当前对象发送出去的operation, 存放在静态区的一个变量, 并且生命周期跟app同步, 只有一个存储地址
static char loadOperationKey;

@implementation UIView (WebCacheOperation)

/**
 * 关联一个属性用来存放当前加载的operations
 */
- (NSMutableDictionary *)operationDictionary {
    // 利用runtime 用loadOperationKey 唯一地址当作对象属性名来获取内部NSMutableDictionary 类型operations值, 为什么是NSMutableDictionary 因为
    NSMutableDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
    // 取到直接返回
    if (operations) {
        return operations;
    }
    
    // 如果此属性没有值 就创建一个 NSMutableDictionary变量
    operations = [NSMutableDictionary dictionary];
    // 并且利用runtime 根据loadOperationKey地址作为属性名 赋值
    objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // 返回
    return operations;
}

- (void)sd_setImageLoadOperation:(id)operation forKey:(NSString *)key {
    // 根据key取消当前对象对应key的operations加载
    [self sd_cancelImageLoadOperationWithKey:key];
    // 获取内部的operationDictionary
    NSMutableDictionary *operationDictionary = [self operationDictionary];
    // 把最新的operation 根据key存放进去
    [operationDictionary setObject:operation forKey:key];
}

- (void)sd_cancelImageLoadOperationWithKey:(NSString *)key {
    // 获取内部的operationDictionary
    NSMutableDictionary *operationDictionary = [self operationDictionary];
    // 根据key 把对应当前的operation取出
    id operations = [operationDictionary objectForKey:key];
    // 如果有值
    if (operations) {
        // 值等于数组 取消全部的operations
        if ([operations isKindOfClass:[NSArray class]]) {
            for (id <SDWebImageOperation> operation in operations) {
                if (operation) {
                    [operation cancel];
                }
            }
        }// 取消单个对象
        else if ([operations conformsToProtocol:@protocol(SDWebImageOperation)]){
            [(id<SDWebImageOperation>)operations cancel];
        }
        // 取消完之后移除对应key的value值 operations
        [operationDictionary removeObjectForKey:key];
    }
}

- (void)sd_removeImageLoadOperationWithKey:(NSString *)key {
    NSMutableDictionary *operationDictionary = [self operationDictionary];
    [operationDictionary removeObjectForKey:key];
}

@end
