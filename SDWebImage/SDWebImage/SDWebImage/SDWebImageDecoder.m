#import "SDWebImageDecoder.h"

@implementation UIImage (ForceDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image {
    // image为nil不适合
    if (image == nil) {
        return nil;
    }
    
    @autoreleasepool{
        // animated images 动图不适合
        if (image.images != nil) {
            return image;
        }
        
        // 通过CGImageRef拿到图像有关的各种参数
        CGImageRef imageRef = image.CGImage;
        
        // 透明度
        CGImageAlphaInfo alpha = CGImageGetAlphaInfo(imageRef);
        // 带有透明因素的图像不适合
        BOOL anyAlpha = (alpha == kCGImageAlphaFirst ||
                         alpha == kCGImageAlphaLast ||
                         alpha == kCGImageAlphaPremultipliedFirst ||
                         alpha == kCGImageAlphaPremultipliedLast);
        // 判断要不要解码
        if (anyAlpha) {
            return image;
        }
        
        CGColorSpaceModel imageColorSpaceModel = CGColorSpaceGetModel(CGImageGetColorSpace(imageRef));
        // 颜色空间
        CGColorSpaceRef colorspaceRef = CGImageGetColorSpace(imageRef);
        
        BOOL unsupportedColorSpace = (imageColorSpaceModel == kCGColorSpaceModelUnknown ||
                                      imageColorSpaceModel == kCGColorSpaceModelMonochrome ||
                                      imageColorSpaceModel == kCGColorSpaceModelCMYK ||
                                      imageColorSpaceModel == kCGColorSpaceModelIndexed);
        if (unsupportedColorSpace) {
            colorspaceRef = CGColorSpaceCreateDeviceRGB();
        }
        
        // 宽
        size_t width = CGImageGetWidth(imageRef);
        // 高
        size_t height = CGImageGetHeight(imageRef);
        // 用来说明每个像素占用内存多少个字节，在这里是占用4个字节。（图像在iOS设备上是以像素为单位显示的）
        NSUInteger bytesPerPixel = 4;
        // 计算出每行的像素数
        NSUInteger bytesPerRow = bytesPerPixel * width;
        // 表示每一个组件占多少位。这个不太好理解，我们先举个例子，比方说RGBA，其中R（红色）G（绿色）B（蓝色）A（透明度）是4个组件，每个像素由这4个组件组成，那么我们就用8位来表示着每一个组件，所以这个RGBA就是8*4 = 32位。
        NSUInteger bitsPerComponent = 8;
        
        // 创建没有透明因素的bitmap graphics contexts
        // 注意：这里创建的context是没有透明因素的。在UI渲染的时候，实际上是把多个图层按像素叠加计算的过程，需要对每一个像素进行 RGBA 的叠加计算。当某个 layer 的是不透明的，也就是 opaque 为 YES 时，GPU 可以直接忽略掉其下方的图层，这就减少了很多工作量。这也是调用 CGBitmapContextCreate 时 bitmapInfo 参数设置为忽略掉 alpha 通道的原因。
        CGContextRef context = CGBitmapContextCreate(NULL,
                                                     width,
                                                     height,
                                                     bitsPerComponent,
                                                     bytesPerRow,
                                                     colorspaceRef,
                                                     kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast);
        
        // 绘制图像到context
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        // 生成 imageRef
        CGImageRef imageRefWithoutAlpha = CGBitmapContextCreateImage(context);
        // 获取image
        UIImage *imageWithoutAlpha = [UIImage imageWithCGImage:imageRefWithoutAlpha
                                                         scale:image.scale
                                                   orientation:image.imageOrientation];
        
        if (unsupportedColorSpace) {
            CGColorSpaceRelease(colorspaceRef);
        }
        
        CGContextRelease(context);
        CGImageRelease(imageRefWithoutAlpha);
        
        return imageWithoutAlpha;
    }
}

@end
