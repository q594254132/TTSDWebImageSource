//
// Created by Fabrice Aneche on 06/01/14.
// Copyright (c) 2014 Dailymotion. All rights reserved.
//

#import "NSData+ImageContentType.h"


@implementation NSData (ImageContentType)

/**
 *  计算图像数据的内容类型 在从缓存中获取到data的时候调用判断什么类型
 *
 *  @param data 传进来的数据
 *
 *  @return 返回数据的类型 (也就是 image/jpeg, image/gif)
 */
+ (NSString *)sd_contentTypeForImageData:(NSData *)data {
    uint8_t c;
    // 文件在16进制存储都会有一个文件头, 用来存储文件的类型信息, 所以获取data中的前一个字节数就知道是什么类型的图片, 当然如果还有其他文件就需要获取前4个字节, 甚至更多
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
        case 0x52:
            // R as RIFF for WEBP
            if ([data length] < 12) {
                return nil;
            }
            NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                return @"image/webp";
            }

            return nil;
    }
    return nil;
}

@end


@implementation NSData (ImageContentTypeDeprecated)

+ (NSString *)contentTypeForImageData:(NSData *)data {
    return [self sd_contentTypeForImageData:data];
}

@end
