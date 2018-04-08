//
//  FanVideoFrame.h
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/9.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import "FanFrame.h"

@interface FanVideoFrame : FanFrame
@property(nonatomic,strong)NSData *sps;
@property(nonatomic,strong)NSData *pps;
@property(nonatomic,assign)BOOL keyFrame;
@end
