//
//  FFMPEG264Manager.h
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/7.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FANSoftEncoderDelegate.h"
@interface FFMPEG264Manager : NSObject<FANSoftEncoderDelegate>

- (instancetype)initWithWidth:(int)width height:(int)height fileName:(NSString *)fileName;



- (int)setX264Resource;
@end
