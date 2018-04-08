//
//  FANVideoCapture.h
//  FanLiveing
//
//  Created by hyf on 16/7/30.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@class FANVideoCapture;
@protocol FANVideoCaptureDelegate <NSObject>

- (void)FANVideoCapture :(FANVideoCapture *)videoCapture didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

@interface FANVideoCapture : NSObject


@property(nonatomic,assign)BOOL startRunning;
@property(nonatomic,strong) AVCaptureVideoPreviewLayer *recordLayer;
@property(nonatomic,assign) id<FANVideoCaptureDelegate> delegate;
@end
