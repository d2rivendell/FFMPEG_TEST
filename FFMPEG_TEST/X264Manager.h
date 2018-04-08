//
//  X264Manager.h
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/7.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FANSoftEncoderDelegate.h"
@class X264Manager,FanFrame;

@protocol X264ManagerDelegate <NSObject>

- (void)X264Manager:(X264Manager *)manager didEncoderh264Data:(NSData *)h264data;
- (void)X264Manager:(X264Manager *)manager didEncoderFrame:(FanFrame *)frame;
@end

@interface X264Manager : NSObject<FANSoftEncoderDelegate>

- (instancetype)initWithWidth:(int)width height:(int)height fileName:(NSString *)fileName;

- (void)setupX264;

@property(nonatomic,assign)id<X264ManagerDelegate> delegate;
@end
