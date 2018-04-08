//
//  RTMPStreamer.h
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/8.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FanVideoFrame;
@interface RTMPStreamer : NSObject
- (void)sendVideoFrame:(FanVideoFrame *)videoFrame;
+ (instancetype)shareStreamer;

- (instancetype)initWithRTMP_Url:(char *)rtmpUrl;
@end
