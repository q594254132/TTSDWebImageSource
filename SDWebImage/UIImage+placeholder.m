//
//  UIImage+placeholder.m
//  Test
//
//  Created by 陶建 on 16/11/3.
//  Copyright © 2016年 taoJ. All rights reserved.
//

#import "UIImage+placeholder.h"

@implementation UIImage (placeholder)

+ (instancetype)imageWithNamed:(NSString *)name fillColor:(UIColor *)color backgroundSize:(CGSize)size {
    UIImage *image = [UIImage imageNamed:name];
    return [image fillColor:color backgroundSize:size];
}

- (instancetype)fillColor:(UIColor *)color backgroundSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, false, 0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, size.width, size.height)];
    [color setFill];
    [path fill];
    CGFloat imageX = (size.width - self.size.width) * 0.5;
    CGFloat imageY = (size.height - self.size.height) * 0.5;
    [self drawInRect:CGRectMake(imageX, imageY, self.size.width, self.size.height)];
    
    return UIGraphicsGetImageFromCurrentImageContext();
}

@end
