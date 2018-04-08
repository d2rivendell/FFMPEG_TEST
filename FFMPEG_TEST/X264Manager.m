//
//  X264Manager.m
//  iosStream
//
//  Created by hyf on 16/6/5.
//  Copyright © 2016年 HYF. All rights reserved.
//

#import "X264Manager.h"
#import "FanVideoFrame.h"
#import "RTMPStreamer.h"
#include <stdio.h>
#include <stdlib.h>
#include "stdint.h"

#if defined ( __cplusplus)
extern "C"
{
#include "x264.h"
};
#else
#include "x264.h"
#endif


@interface X264Manager ()
{
    x264_nal_t *pNal;
    x264_param_t *param;
    x264_picture_t *pPicIn;
    x264_picture_t *pPicOut;
    
    x264_t *pHandle;
    int nal;// 循环标记
    
    int csp;
    
    long frame_num ;//要解压多少帧
    int y_size;//y分量的size
    
    
    int k;
    FILE *fp;
}
@property(nonatomic,assign)int  height;
@property(nonatomic,assign)int  width;
@property(nonatomic,strong)RTMPStreamer *streamer;

@end

@implementation X264Manager

- (instancetype)initWithWidth:(int)width height:(int)height fileName:(NSString *)fileName
{
    self = [super init];
    if (self) {
        self.width = width;
        self.height = height;
        [self initForFilePathWithName:fileName];
        [self setupX264];
        _streamer = [[RTMPStreamer alloc] initWithRTMP_Url:"rtmp://192.168.0.103:1935/rtmplive/room"];
    }
    return self;
}


- (void)setupX264{
    
    csp = X264_CSP_I420;
    if(!self.height || !self.width){
        
        self.width = 480;
        self.height = 360;
    }
    nal = 0;
    pPicIn = (x264_picture_t *)malloc(sizeof(x264_picture_t));
    pPicOut = (x264_picture_t *)malloc(sizeof(x264_picture_t));
    param = (x264_param_t *)malloc(sizeof(x264_param_t));
    
    //x264_param_default(param);
    
    //#####################################
    //Param
    
    x264_param_default_preset(param, "fast" , "zerolatency" );//能即时编码
    param->rc.b_mb_tree=0;//这个不为0,将导致编码延时帧...在实时编码时,必须为0
    param->i_log_level  = X264_LOG_DEBUG;
    param->i_threads  = X264_SYNC_LOOKAHEAD_AUTO;
    param->i_frame_total = 0;
    param->i_keyint_max = 10;
    param->i_bframe  = 5;
    param->b_open_gop  = 0;
    param->i_bframe_pyramid = 0;
    param->rc.i_qp_constant=0;//是实际质量，越大图像越花，越小越清晰。
    param->rc.i_qp_max=0;
    param->rc.i_qp_min=0;
    param->i_bframe_adaptive = X264_B_ADAPT_TRELLIS;
    param->i_fps_den  = 15;
    param->i_fps_num  = 1;
    param->i_timebase_den = 15;
    param->i_timebase_num = 1;
    
    param->rc.i_rc_method = X264_RC_ABR;//参数i_rc_method表示码率控制，CQP(恒定质量)，CRF(恒定码率)，ABR(平均码率)
    param->b_repeat_headers = 1;//使用实时视频传输时，需要实时发送sps,pps数据 该参数设置是让每个I帧都附带sps/pps。
    
    //. I帧间隔 我是将I帧间隔与帧率挂钩的，以控制I帧始终在指定时间内刷新。 以下是2秒刷新一个I帧
    
    param->rc.i_bitrate = 5;
    
    param->i_level_idc=30;// 编码复杂度
    //#####################################
    param->i_width = self.width;
    param->i_height = self.height;
    param->i_csp = csp;
    x264_param_apply_profile(param, x264_profile_names[5]);
    
    pHandle = x264_encoder_open(param);
    
    x264_picture_init(pPicOut);
    x264_picture_alloc(pPicIn, csp, param->i_width , param->i_height);
    
    
    y_size = param->i_width * param->i_height;
    frame_num = 0;
    
}

- (void)encoderYUV_to_x264WithSourceFile:( char *)src andDes:( char *)des{
    
    
    int i,j,ret;
    FILE *fp_src = fopen(src, "rb");
    FILE *fp_des = fopen(des, "wb");
    if(fp_des == NULL || fp_src == NULL){
        printf("open file error!");
        return;
    }
    
    if(frame_num == 0){
        fseek(fp_src, 0, SEEK_END);
        switch (csp) {
            case X264_CSP_I444:
                frame_num = ftell(fp_src)/(y_size * 3); break;
                break;
            case X264_CSP_I420:frame_num = ftell(fp_src)/(y_size *3/2); break;
            default:
                printf("ColorSpace not support");
                return;
                break;
        }
        fseek(fp_src, 0, SEEK_SET);
    }
    
    for (i = 0; i < frame_num; i++) {
        switch (csp) {
            case X264_CSP_I444:{
                fread(pPicIn->img.plane[0], y_size, 1, fp_src);//y
                fread(pPicIn->img.plane[1], y_size, 1, fp_src);//u
                fread(pPicIn->img.plane[2], y_size, 1, fp_src);//v
                break;
            }
            case X264_CSP_I420:{
                fread(pPicIn->img.plane[0], y_size, 1, fp_src);//y
                fread(pPicIn->img.plane[1], y_size/4, 1, fp_src);//u
                fread(pPicIn->img.plane[2], y_size/4, 1, fp_src);//v
                break;
            }
            default:{
                printf("Colorspace Not Support.\n");
                return;
                break;
            }
        }
        pPicIn->i_pts = i;
        //开始编码
        ret = x264_encoder_encode(pHandle, &pNal, &nal, pPicIn, pPicOut);
        if(ret < 0)
        {
            printf("Error.\n");
            return;
        }
        printf(" nal = %d encode  %d frame\n",nal,i);
        for (j= 0;j < nal; j++) {
            fwrite(pNal[j].p_payload, 1, pNal[j].i_payload, fp_des);
        }
    }
    
    
    //flush encoder
    while (1) {
#warning 此处 为pPicIn 为 NULL
        //
        ret = x264_encoder_encode(pHandle, &pNal, &nal, NULL, pPicOut);
        if(ret == 0)
        {
            break;
        }
        printf("flush %d frame\n",i);
        for (j= 0;j < nal; j++) {
            fwrite(pNal[j].p_payload, 1, pNal[j].i_payload, fp_des);
        }
        i++;
    }
    x264_picture_clean(pPicIn);
    x264_encoder_close(pHandle);
    pHandle = NULL;
    
    free(pPicIn);
    free(pPicOut);
    free(param);
    
    fclose(fp_src);
    fclose(fp_des);
    
}

- (void)encoderSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    frame_num = 0;
    
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess)
        return;
    
    
    uint8_t *pY =  CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint8_t *pUV =  CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    size_t pWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t pHeight = CVPixelBufferGetHeight(pixelBuffer);
    
    //y 每row的size
    size_t bytesOfRow0 =  CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    //uv每row的size
    size_t bytesOfRow1 =  CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    
    
    for(int i =0;i<pHeight;i++)//复制Y数据
    {
        memcpy(pPicIn->img.plane[0]+i*pWidth,pY+i* bytesOfRow0,pWidth);
    }
    uint8_t *pDst1 = pPicIn->img.plane[1];
    uint8_t *pDst2 = pPicIn->img.plane[2];
    for(int j = 0;j<pHeight/2;j++)//把UV数据重排
    {
        for(int i =0;i<pWidth/2;i++)
        {
            *(pDst1++) = pUV[i<<1];
            *(pDst2++) = pUV[(i<<1) + 1];
        }
        pUV+=bytesOfRow1;
    }
    pPicIn->i_pts = k++;
    pPicIn->i_dts = pPicIn->i_pts;
    
    int ret = x264_encoder_encode(pHandle, &pNal, &nal, pPicIn, pPicOut);
    if(ret == 0){
        
        printf("error  encoder! \n");
        return;
    }
  
    NSLog(@"~~~~begin~~~");
    
    NSMutableData *h264Data = [NSMutableData data];
    int spsLen = 0, ppsLen = 0;
    for (int  j= 0;j < nal; j++) {
        printf("succed %d frame  size = %d\n",k,pNal[j].i_payload);
        fwrite(pNal[j].p_payload, 1, pNal[j].i_payload, fp);
        
        FanVideoFrame *frame = [[FanVideoFrame alloc] init];
        if(pNal[j].i_type == NAL_SPS){
            spsLen = pNal[j].i_payload - 4;// 除去 00 00 00 01
            frame.sps = [NSData dataWithBytes:(pNal[j].p_payload + 4) length:spsLen];
        } else if(pNal[j].i_type == NAL_PPS){
            ppsLen = pNal[j].i_payload - 4;// 除去 00 00 00 01
            frame.pps = [NSData dataWithBytes:(pNal[j].p_payload + 4) length:ppsLen];
            frame.keyFrame = YES;
            [self.streamer sendVideoFrame:frame];
        }else{
            frame.data = [NSData dataWithBytes:pNal[j].p_payload length:pNal[j].i_payload];
            [self.streamer  sendVideoFrame:frame];
        }
        
    [h264Data appendBytes:pNal[j].p_payload length:pNal[j].i_payload];
        switch (pNal[j].i_type) {
            case NAL_UNKNOWN:
                NSLog(@"i_type = NAL_UNKNOWN");
                break;
            case NAL_SLICE:
                 NSLog(@"i_type = NAL_SLICE");
                break;
            case NAL_SLICE_DPA:
                NSLog(@"i_type = NAL_SLICE_DPA");
                break;
            case NAL_SLICE_DPB:
                 NSLog(@"i_type = NAL_SLICE_DPB");
                break;
            case NAL_SLICE_DPC:
                NSLog(@"i_type = NAL_SLICE_DPC");
                break;
            case NAL_SLICE_IDR:
                NSLog(@"i_type = NAL_SLICE_IDR");
                break;
            case NAL_SEI:
                NSLog(@"i_type = NAL_SEI");
                break;
            case NAL_SPS:
                NSLog(@"i_type = NAL_SPS");
                break;
            case NAL_PPS:
                NSLog(@"i_type = NAL_PPS");
            case NAL_AUD:
                NSLog(@"i_type = NAL_AUD");
            case NAL_FILLER:
                NSLog(@"i_type = NAL_FILLER");
                break;
                
            default:
                break;
        }
        if(h264Data.length > 0){
            if([self.delegate respondsToSelector:@selector(X264Manager:didEncoderh264Data:)]){
                [self.delegate X264Manager:self didEncoderh264Data:h264Data];
            }
        }
    }
      NSLog(@"~~~~end~~~");
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}


- (void)stop
{
    
    while (1) {
        int ret = x264_encoder_encode(pHandle, &pNal, &nal, NULL, pPicOut);
        if(ret == 0){
            
            printf("error  encoder! \n");
            break;
        }
        
        printf("flue %d frame\n",k);
          NSMutableData *h264Data = [NSMutableData data];
        for (int  j= 0;j < nal; j++) {
            fwrite(pNal[j].p_payload, 1, pNal[j].i_payload, fp);
             [h264Data appendBytes:pNal[j].p_payload length:pNal[j].i_payload];
        }
        if(h264Data.length > 0){
            if([self.delegate respondsToSelector:@selector(X264Manager:didEncoderh264Data:)]){
                [self.delegate X264Manager:self didEncoderh264Data:h264Data];
            }
        }
        
    }
    
    x264_picture_clean(pPicIn);
    x264_encoder_close(pHandle);
    pHandle = NULL;
    free(pPicIn);
    pPicIn = NULL;
    free(pPicOut);
    pPicOut = NULL;
    free(param);
    param = NULL;
    fclose(fp);
    fp = NULL;
}

- (void)initForFilePathWithName:(NSString *)fileName{
    
    char *path = [self GetFilePathByfileName:fileName];
    
    NSLog(@"%s",path);
    
    fp = fopen(path,"wb");
    
}


- (char*)GetFilePathByfileName:(NSString*)filename
{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *strName = [NSString stringWithFormat:@"%@",filename];
    
    
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:strName];
    
    
    
    long len = [writablePath length];
    
    
    
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    
    
    
    [writablePath getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    
    NSLog(@"patn = %s",filepath);
    return filepath;
    
}
@end
