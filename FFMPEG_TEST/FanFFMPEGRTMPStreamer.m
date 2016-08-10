//
//  FanFFMPEGRTMPStreamer.m
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/7.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import "FanFFMPEGRTMPStreamer.h"
#ifdef __cplusplus
extern "C" {
#endif
#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
#include <libavutil/time.h>
    
#ifdef __cplusplus
};
#endif
@implementation FanFFMPEGRTMPStreamer


int read_buffer(void *opaque, uint8_t *buf, int buf_size){
    FanFFMPEGRTMPStreamer *streamer = (__bridge FanFFMPEGRTMPStreamer *)opaque;
    if(streamer.h264Data){
         memcpy(&buf, streamer.h264Data.bytes, sizeof(streamer.h264Data.bytes));
        return (int)streamer.h264Data.length;
    }
    return -1;
}
- (void)streamer{
  //  char input_str_full[500]={0};
    char output_str_full[500]={0};
    
//    NSString *input_str= [NSString stringWithFormat:@"resource.bundle/%@",@"likeMoonth.h264"];
//    NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
//    NSString *local = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
//    NSString *localPath = [local stringByAppendingPathComponent:@"fander.flv"];
//    NSLog(@"local = %@",localPath);
//    sprintf(input_str_full,"%s",[input_nsstr UTF8String]);
    sprintf(output_str_full,"%s",[@"rtmp://192.168.0.103:1935/rtmplive/room" UTF8String]);
    

    
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    char in_filename[500]={0};
    char out_filename[500]={0};
    int ret, i;
    int videoindex=-1;
    int frame_index=0;
    int64_t start_time=0;
    
   // strcpy(in_filename,input_str_full);
    strcpy(out_filename,output_str_full);
    
    av_register_all();
    avformat_network_init();
    ifmt_ctx=avformat_alloc_context();
    
    unsigned char* inbuffer=NULL;

    inbuffer=(unsigned char*)av_malloc(32768);

    AVIOContext *avio_in=NULL;

    avio_in =avio_alloc_context(inbuffer, 32768,0,NULL,read_buffer,NULL,NULL);
    ifmt_ctx->pb=avio_in;
    ifmt_ctx->flags=AVFMT_FLAG_CUSTOM_IO;
    
    ret = avformat_open_input(&ifmt_ctx, "whatever", NULL, 0);
    if(ret < 0){
        NSLog(@"打开文件失败");
        goto end;
    }
    
    ret = avformat_find_stream_info(ifmt_ctx, 0);
    if(ret < 0){
        NSLog(@"find stream fail");
        goto end;
    }
    
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        if(ifmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            videoindex = i ;
            break;
        }
    }
    
    av_dump_format(ifmt_ctx, 0, in_filename, 0);
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename);//rtmp
    if(!ofmt_ctx){
        NSLog(@"初始化outputFormat fail");
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *inStream = ifmt_ctx->streams[i];
        AVStream *outStream = avformat_new_stream(ofmt_ctx, inStream->codec->codec);
        if(!outStream){
            NSLog(@"fail to new stream");
            goto end;
        }
        ret = avcodec_copy_context(outStream->codec, inStream->codec);
        if (ret < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        outStream->codec->codec_tag = 0;
        if(ofmt_ctx->oformat->flags | AVFMT_GLOBALHEADER){
            outStream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        }
    }
    
    
    //dump
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    
    //open outPut url
    if(!(ofmt->flags & AVFMT_NOFILE)){
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if(ret < 0){
            NSLog(@"不能打开外部URL");
            goto end;
        }
    }
    
    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        printf( "Error occurred when opening output URL\n");
        goto end;
    }
    
    start_time = av_gettime();
    while (1) {
        AVStream *inStream , *outStrem;
        ret = av_read_frame(ifmt_ctx, &pkt);
        if(ret < 0) break;
        //write pts
        if(pkt.pts == AV_NOPTS_VALUE){
            AVRational time_base1 = ifmt_ctx->streams[videoindex]->time_base;
            //两个frame 间duration
            int64_t  duration = AV_TIME_BASE/av_q2d(ifmt_ctx->streams[videoindex]->r_frame_rate);
            
            pkt.pts = (duration * frame_index)/(av_q2d(time_base1) * AV_TIME_BASE);
            pkt.dts = pkt.pts;
            pkt.duration = duration/(av_q2d(time_base1) * AV_TIME_BASE);
        }
        //延迟
        if (pkt.stream_index == videoindex){
            AVRational timebase = ifmt_ctx->streams[videoindex]->time_base;
            
            int64_t pts_time = av_rescale_q(pkt.dts, timebase, AV_TIME_BASE_Q);
            int64_t now_time = av_gettime() - start_time;
            
            if(pts_time > now_time){
                av_usleep(pts_time - now_time);
            }
        }
        //输入pts dts 转换 pts dts 到输出
        inStream = ifmt_ctx->streams[pkt.stream_index];
        outStrem = ofmt_ctx->streams[pkt.stream_index];
        
        pkt.pts = av_rescale_q_rnd(pkt.pts, inStream->time_base, outStrem->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.dts = av_rescale_q_rnd(pkt.dts, inStream->time_base, outStrem->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.duration = av_rescale_q(pkt.duration, inStream->time_base, outStrem->time_base);
        pkt.pos = -1;///< byte position in stream, -1 if unknown
        if(pkt.stream_index ==videoindex){
            NSLog(@"send %8d video to url",frame_index);
            ++frame_index;
        }
        ret  = av_interleaved_write_frame(ofmt_ctx, &pkt);
        if (ret < 0) {
            printf( "Error muxing packet\n");
            break;
        }
        av_free_packet(&pkt);
    }//while  end
    av_write_trailer(ofmt_ctx);
end:
    avformat_close_input(&ifmt_ctx);
    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
        avio_close(ofmt_ctx->pb);
    avformat_free_context(ofmt_ctx);
    if (ret < 0 && ret != AVERROR_EOF) {
        printf( "Error occurred.\n");
        return;
    }
    return;
    
    
}
@end
