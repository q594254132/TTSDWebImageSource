/*
 * 问: 此类干嘛用的?
 * 答: 对UIView扩充的一个分类, 主要作用: 利用运行时根据key, 把要加载图片的operations存储到当前view对象当中
 */

#import <UIKit/UIKit.h>
#import "SDWebImageManager.h"

@interface UIView (WebCacheOperation)

/**
 *  Set the image load operation (storage in a UIView based dictionary)
 *  根据key 把operations存在当前对象中
 *
 *  @param operation the operation
 *  @param key       key for storing the operation
 */
- (void)sd_setImageLoadOperation:(id)operation forKey:(NSString *)key;

/**
 *  Cancel all operations for the current UIView and key
 * 取消key对应的operations操作
 *
 *  @param key key for identifying the operations
 */
- (void)sd_cancelImageLoadOperationWithKey:(NSString *)key;

/**
 *  Just remove the operations corresponding to the current UIView and key without cancelling them
 * 移除key对应的value值operations, 但是没有cancel 这些oprations
 *
 *  @param key key for identifying the operations
 */
- (void)sd_removeImageLoadOperationWithKey:(NSString *)key;

@end
