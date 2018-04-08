//
//  ViewController.m
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/6.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import "ViewController.h"
#import "FANVideoCapture.h"
#import "H264Manager.h"

@interface ViewController ()<FANVideoCaptureDelegate>
@property(nonatomic,strong)UIButton *startBtn;
@property(nonatomic,strong)FANVideoCapture *capture;
@property(nonatomic,strong)H264Manager *h264manager;


@end

@implementation ViewController
- (UIButton *)startBtn
{
    if(_startBtn == nil)
    {
        _startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_startBtn setTitle:@"开始" forState:UIControlStateNormal];
        [_startBtn setTitle:@"暂停" forState:UIControlStateSelected];
        _startBtn.frame = CGRectMake( (WIDTH - 50)/2.0, (HEIGHT - 50 - 50), 50, 50);
        [_startBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        _startBtn.layer.borderColor = [UIColor redColor].CGColor;
        _startBtn.layer.borderWidth = 1;
        _startBtn.layer.cornerRadius = 25;
        [self.view insertSubview:_startBtn atIndex:5];
    }
    return _startBtn;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self addCapture];
    [self.startBtn addTarget:self action:@selector(Start:) forControlEvents:UIControlEventTouchUpInside];
  
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)Start:(UIButton *)btn{
    btn.selected = !btn.selected;
    if(btn.selected){
        self.capture.startRunning = YES;
    }else{
      self.capture.startRunning = NO;
        [self.h264manager.encoder stop];
    }

}
- (void)addCapture{
    self.capture = [[FANVideoCapture alloc] init];
    self.capture.delegate = self;
    [self.view.layer addSublayer:self.capture.recordLayer];
  //  [self.encoder setX264Resource];
    
}
- (void)FANVideoCapture:(FANVideoCapture *)videoCapture didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
     
    [self.h264manager.encoder encoderSampleBuffer:sampleBuffer];

}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (H264Manager *)h264manager{
    if(_h264manager == nil){
        _h264manager = [[H264Manager alloc] initWithEncodeType:X264Encoder width:480 height:360 fileName:@"wodejuanjuan.h264"];
    }
    return _h264manager;
}


#pragma mark -- 锁定屏幕为竖屏
- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}




@end
