/* 加载gif图片的时候会用到这个分类
 * 注意: 如果要获取一个图片的尺寸, 不是直接使用image.size, 而是使用image.size * image.scale
 */

#import <UIKit/UIKit.h>

@interface UIImage (GIF)

/**
 * 根据名称获取图片
 */
+ (UIImage *)sd_animatedGIFNamed:(NSString *)name;

/**
 * 根据NSData获取图片
 */
+ (UIImage *)sd_animatedGIFWithData:(NSData *)data;

/**
 * 修改图片到指定的尺寸
 */
- (UIImage *)sd_animatedImageByScalingAndCroppingToSize:(CGSize)size;

@end
