//
//  FANVideoCapture.m
//  FanLiveing
//
//  Created by hyf on 16/7/30.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import "FANVideoCapture.h"





#define h264outputWidth 368
#define h264outputHeight 640
@interface FANVideoCapture ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    dispatch_semaphore_t _lock;
}
@property(nonatomic,strong)AVCaptureSession *captureSession;
@property(nonatomic,strong)AVCaptureDevice *cameraDevice;
@property(nonatomic,strong)AVCaptureDeviceInput *deviceInput;
@property(nonatomic,strong)AVCaptureVideoDataOutput *dataOutput;
@property(nonatomic,strong)AVCaptureConnection *captureConnection;//判断是视频还是音频


@property (nonatomic, assign) uint64_t timestamp;

@end

@implementation FANVideoCapture


- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupCamera];
    }
    return self;
}
- (int)setupCamera{

    self.captureSession = [[AVCaptureSession alloc] init];
    //    captureSession.sessionPreset = AVCaptureSessionPresetHigh;
     self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    
    
    self.cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
     self.deviceInput  = [AVCaptureDeviceInput deviceInputWithDevice:self.cameraDevice  error:&error];
    
    if([self.captureSession  canAddInput:self.deviceInput])
        [self.captureSession  addInput:self.deviceInput];
    else
        NSLog(@"Error: %@", error);
    
    dispatch_queue_t queue = dispatch_queue_create("myEncoderH264Queue", NULL);
    
    self.dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.dataOutput  setSampleBufferDelegate:self queue:queue];
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                              kCVPixelBufferPixelFormatTypeKey,
                              nil]; // X264_CSP_NV12
    self.dataOutput .videoSettings = settings;
    self.dataOutput .alwaysDiscardsLateVideoFrames = YES;
    
    if ([self.captureSession canAddOutput:self.dataOutput]) {
        [self.captureSession addOutput:self.dataOutput];
    }
    
    // 保存Connection，用于在SampleBufferDelegate中判断数据来源（是Video/Audio？）
    self.captureConnection = [self.dataOutput connectionWithMediaType:AVMediaTypeVideo];
    
#pragma mark -- AVCaptureVideoPreviewLayer init
    self.recordLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.recordLayer.frame = CGRectMake(0, 0, WIDTH, HEIGHT);
    self.recordLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; // 设置预览时的视频缩放方式
    [[self.recordLayer connection] setVideoOrientation:AVCaptureVideoOrientationPortrait]; // 设置视频的朝向

    return 1;
}

- (void)setStartRunning:(BOOL)startRunning{
   
    _startRunning = startRunning;
    if(_startRunning){
    [self.captureSession startRunning];
    }else{
     [self.captureSession stopRunning];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if(self.captureConnection == connection){
     if([self.delegate respondsToSelector:@selector(FANVideoCapture:didOutputSampleBuffer:)]){
        
         [self.delegate FANVideoCapture:self didOutputSampleBuffer:sampleBuffer];
        }
    
    }

}
@end
