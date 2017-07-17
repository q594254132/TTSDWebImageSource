/** 根据二进制的数据获取图片的contentTyp
 * JPEG (jpg)，文件头：FFD8FFE1
 * PNG (png)，文件头：89504E47
 * GIF (gif)，文件头：47494638
 * TIFF tif;tiff 0x49492A00
 * TIFF tif;tiff 0x4D4D002A
 * RAR Archive (rar)，文件头：52617221
 * WebP : 524946462A73010057454250
 */

#import <Foundation/Foundation.h>

@interface NSData (ImageContentType)

/**
 *  Compute the content type for an image data
 *
 *  @param data the input data
 *
 *  @return the content type as string (i.e. image/jpeg, image/gif)
 */
+ (NSString *)sd_contentTypeForImageData:(NSData *)data;

@end


@interface NSData (ImageContentTypeDeprecated)

+ (NSString *)contentTypeForImageData:(NSData *)data __deprecated_msg("Use `sd_contentTypeForImageData:`");

@end
