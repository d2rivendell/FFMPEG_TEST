//
//  H264Manager.m
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/6.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import "FFMPEG264Manager.h"



#ifdef __cplusplus
extern "C" {
#endif
    
#include <libavutil/opt.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
    
#ifdef __cplusplus
};
#endif


@interface FFMPEG264Manager()
{
    AVFormatContext   *fmt_ctx;
    AVOutputFormat    *ofmt;
    AVStream          *videoStream;
    AVCodecContext    *codec_ctx;//videoStream 的 AVCodecContext
    AVCodec           *codec;//videoStream 的 codec
    AVPacket          pkt;
    uint8_t           *picture_buff;
    AVFrame           *pFrame;
    char              *out_file;
}
@property(nonatomic,assign)int picture_size;
@property(nonatomic,assign)int frameCount;
@property(nonatomic,assign)int width;
@property(nonatomic,assign) int height;
@property(nonatomic,assign) int y_size;

@end
@implementation FFMPEG264Manager


- (instancetype)initWithWidth:(int)width height:(int)height fileName:(NSString *)fileName
{
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        [self setFileSavedPath:fileName];
        if( [self setX264Resource] == -1){
            NSLog(@"初始化失败");
        }
    }
    return self;
}

- (int)setX264Resource{
    _frameCount = 0;
    
    // AVCaptureSessionPresetMedium
   
    
    av_register_all(); // 注册FFmpeg所有编解码器
    
    //Method1.
    fmt_ctx = avformat_alloc_context();
    //Guess Format
    ofmt = av_guess_format(NULL, out_file, NULL);
    fmt_ctx->oformat = ofmt;
    
    // Method2.
    // avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
    // fmt = pFormatCtx->oformat;
    
    //Open output URL
    if (avio_open(&fmt_ctx->pb, out_file, AVIO_FLAG_READ_WRITE) < 0){
        printf("Failed to open output file! \n");
        return -1;
    }
    
    videoStream = avformat_new_stream(fmt_ctx, 0);
    videoStream->time_base.num = 1;
    videoStream->time_base.den = 15;
    
    if (videoStream==NULL){
        return -1;
    }
    
    // Param that must set
    codec_ctx = videoStream->codec;
    codec_ctx->codec_id = ofmt->video_codec;
    codec_ctx->codec_type = AVMEDIA_TYPE_VIDEO;
    codec_ctx->pix_fmt = PIX_FMT_YUV420P;
    codec_ctx->width = self.width;
    codec_ctx->height = self.height;
    codec_ctx->time_base.num = 1;
    codec_ctx->time_base.den = 15;
    codec_ctx->bit_rate = 400000;
    codec_ctx->gop_size = 250;
    // H264
    // pCodecCtx->me_range = 16;
    // pCodecCtx->max_qdiff = 4;
    // pCodecCtx->qcompress = 0.6;
    codec_ctx->qmin = 10;
    codec_ctx->qmax = 51;
    
    // Optional Param
    codec_ctx->max_b_frames=3;
    
    // Set Option
    AVDictionary *param = 0;
    
    // H.264
    if(codec_ctx->codec_id == AV_CODEC_ID_H264) {
        
        av_dict_set(&param, "preset", "slow", 0);
        av_dict_set(&param, "tune", "zerolatency", 0);
        // av_dict_set(&param, "profile", "main", 0);
    }
    
    // Show some Information
    av_dump_format(fmt_ctx, 0, out_file, 1);
    
    codec = avcodec_find_encoder(codec_ctx->codec_id);
    if (!codec) {
        
        printf("Can not find encoder! \n");
        return -1;
    }
    
    if (avcodec_open2(codec_ctx, codec,&param) < 0) {
        
        printf("Failed to open encoder! \n");
        return -1;
    }
    
    pFrame = av_frame_alloc();
    
    avpicture_fill((AVPicture *)pFrame, picture_buff, codec_ctx->pix_fmt, codec_ctx->width, codec_ctx->height);
    
    //Write File Header
    avformat_write_header(fmt_ctx, NULL);
    
    av_new_packet(&pkt, _picture_size);
    
    _y_size = codec_ctx->width * codec_ctx->height;
    
    return 0;
    
}
- (void)encoderSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        NSLog(@"%@",[NSThread currentThread]);
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        size_t bytesrow0 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        size_t bytesrow1  = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height *3/ 2); // buffer to store YUV with layout YYYYYYYYUUVV
        
        /* convert NV12 data to YUV420*/
        UInt8 *pY = bufferPtr ;
        UInt8 *pUV = bufferPtr1;
        
        UInt8 *pU = yuv420_data + width*height;
        UInt8 *pV = pU + width*height/4;
        for(int i =0;i<height;i++)//复制Y数据
        {
            memcpy(yuv420_data+i*width,pY+i*bytesrow0,width);
        }
        for(int j = 0;j<height/2;j++)//把UV数据重排
        {
            for(int i =0;i<width/2;i++)
            {
                *(pU++) = pUV[i<<1];
                *(pV++) = pUV[(i<<1) + 1];
            }
            pUV+=bytesrow1;
        }
        
        //Read raw YUV data
        picture_buff = yuv420_data;
        pFrame->data[0] = picture_buff;              // Y
        pFrame->data[1] = picture_buff+ _y_size;      // U
        pFrame->data[2] = picture_buff+ _y_size*5/4;  // V
        
        // PTS
        pFrame->pts = _frameCount;
        int got_picture = 0;
        
        // Encode
        pFrame->width = self.width;
        pFrame->height = self.height;
        pFrame->format = PIX_FMT_YUV420P;
        
        int ret = avcodec_encode_video2(codec_ctx, &pkt, pFrame, &got_picture);
        if(ret < 0) {
            
            printf("Failed to encode! \n");
            
        }
        if (got_picture==1) {
            
            printf("Succeed to encode frame: %5d\tsize:%5d\n", _frameCount, pkt.size);
            _frameCount++;
            pkt.stream_index = videoStream->index;
            ret = av_write_frame(fmt_ctx, &pkt);
            av_free_packet(&pkt);
        }
        
        free(yuv420_data);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

}

- (void)stop{
    int ret = [self flush_encoder:fmt_ctx streamIndex:0];
    if (ret < 0) {
        
        printf("Flushing encoder failed\n");
    }
    
    //Write file trailer
    av_write_trailer(fmt_ctx);
    
    //Clean
    if (videoStream){
        avcodec_close(videoStream->codec);
        av_free(pFrame);
        //        av_free(picture_buf);
    }
    avio_close(fmt_ctx->pb);
    avformat_free_context(fmt_ctx);
}

- (int) flush_encoder:(AVFormatContext *)mt_ctx  streamIndex:(unsigned int)stream_index{
    //解码残留片段
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame){
            ret=0;
            break;
        }
        printf("Flush Encoder: Succeed to encode 1 frame!\tsize:%5d\n",enc_pkt.size);
        /* mux encoded frame */
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}


- (void)setFileSavedPath:(NSString *)path
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:path];
    
    out_file = [self nsstring2char:writablePath];
}
- (char*)nsstring2char:(NSString *)path
{
    
    NSUInteger len = [path length];
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    
    [path getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    return filepath;
}
@end
