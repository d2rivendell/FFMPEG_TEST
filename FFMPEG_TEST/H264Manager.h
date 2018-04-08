//
//  H264Manager.h
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/6.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "X264Manager.h"
#import "FFMPEG264Manager.h"
typedef NS_ENUM(NSUInteger,EncoderType) {
  X264Encoder,
  FFMPEGEncoder
};

@interface H264Manager : NSObject
@property(nonatomic,strong)id<FANSoftEncoderDelegate> encoder;

- (instancetype)initWithEncodeType:(EncoderType)type  width:(int)width height:(int)height fileName:(NSString *)fileName;

@end
