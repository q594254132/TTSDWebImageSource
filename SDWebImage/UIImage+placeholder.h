//
//  UIImage+placeholder.h
//  Test
//
//  Created by 陶建 on 16/11/3.
//  Copyright © 2016年 taoJ. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (placeholder)

- (instancetype)fillColor:(UIColor *)color backgroundSize:(CGSize)size;

+ (instancetype)imageWithNamed:(NSString *)name fillColor:(UIColor *)color backgroundSize:(CGSize)size;

@end
