//
//  FANSoftEncoderDelegate.h
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/7.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol FANSoftEncoderDelegate <NSObject>
@required
- (void)encoderSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)stop;

@end
