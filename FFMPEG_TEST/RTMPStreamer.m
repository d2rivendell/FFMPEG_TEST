//
//  RTMPStreamer.m
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/8.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import "RTMPStreamer.h"

#import "FanVideoFrame.h"
#import <QuartzCore/CABase.h>


#ifdef __cplusplus
extern "C" {
#endif
    
#include "rtmp.h"
#include "x264.h"
    
#ifdef __cplusplus
};
#endif
@interface RTMPStreamer()
{
    RTMP *rtmp;
   dispatch_semaphore_t _lock;
}

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) uint64_t currentTimestamp;
@end
@implementation RTMPStreamer

static  RTMPStreamer *_stream;
- (instancetype)init
{
    self = [super init];
    if (self) {
        _lock = dispatch_semaphore_create(1);
    }
    return self;
}

- (uint64_t)currentTimestamp{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if(_isFirstFrame == YES) {
        _timestamp = CACurrentMediaTime()*1000;
        _isFirstFrame = NO;
        currentts = 0;
    }
    else {
        currentts = CACurrentMediaTime()*1000 - _timestamp;
    }
    dispatch_semaphore_signal(_lock);
    return currentts;
}

- (void)sendVideoFrame:(FanVideoFrame *)videoFrame{
    if(videoFrame.keyFrame){
        [self send_sendSps:videoFrame.sps pps:videoFrame.pps];
    }else{
        [self sendVidepData:videoFrame.data];
    }
   
}
- (instancetype)initWithRTMP_Url:(char *)rtmpUrl
{
    self = [super init];
    if (self) {
       rtmp = RTMP_Alloc();
        RTMP_Init(rtmp);
        
       if(!RTMP_SetupURL(rtmp, rtmpUrl)){
         NSLog(@"set up  rtmpUrl fail");
             RTMP_Free(rtmp);
       }
 /*设置可写,即发布流,这个函数必须在连接前使用,否则无效*/
        RTMP_EnableWrite(rtmp);
        /*连接服务器*/
        if(! RTMP_Connect(rtmp, NULL)){
            NSLog(@"连接服务器失败");
            RTMP_Free(rtmp);
        }
        
        /*连接流*/
        if(! RTMP_ConnectStream(rtmp, 0)){
            NSLog(@"连接流失败");
            RTMP_Close(rtmp);
            RTMP_Free(rtmp);
        }
    }
    return self;
}

- (int) send_sendSps:(NSData *)sps pps:(NSData *)pps{
/***定义包体长度***/
    RTMPPacket *packet;
    uint8_t *body;//point to paket m_body
    int len = 1024,i = 0;
    packet = (RTMPPacket *)malloc(RTMP_MAX_HEADER_SIZE + len);
    memset(packet, 0, RTMP_MAX_HEADER_SIZE);
    /*包体内存*/
    packet->m_body = (char *)packet + RTMP_MAX_HEADER_SIZE;
    body = (uint8_t *)packet->m_body;
    packet->m_nBodySize = len;

    /**   包体填充内容*/
    
    unsigned long spsLen = sps.length;
    unsigned long ppsLen = pps.length;
    const char *c_sps = sps.bytes;
    const char *c_pps = pps.bytes;
    body[i++] = 0x17;
    body[i++] = 0x00;
    
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    
    /*AVCDecoderConfigurationRecord*/
    body[i++] = 0x01;
    body[i++] = c_sps[1];
    body[i++] = c_sps[2];
    body[i++] = c_sps[3];
    body[i++] = 0xff;
    
    
    /*----sps---*/
    body[i++] = 0xe1;
    body[i++] = (spsLen >> 8) & 0xff;
    body[i++] = spsLen & 0xff;
    memcpy(&body[i], c_sps, spsLen);
    i += spsLen;
    
    /**---pps---*/
     body[i++] = 0xe1;
     body[i++] = (ppsLen >> 8) & 0xff;
     body[i++] = ppsLen & 0xff;
     memcpy(&body[i], c_pps, ppsLen);
     i += ppsLen;
     
     
    packet->m_hasAbsTimestamp = 0;
    packet->m_nTimeStamp = 0;
    packet->m_nBodySize = i;
    packet->m_packetType = RTMP_PACKET_TYPE_VIDEO; /*此处为类型有两种一种是音频,一种是视频*/
    packet->m_nInfoField2 = rtmp->m_stream_id;
    packet->m_nChannel = 0x04;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
   
    
    /*发送*/
    if (RTMP_IsConnected(rtmp)) {
        RTMP_SendPacket(rtmp,packet,TRUE); /*TRUE为放进发送队列,FALSE是不放进发送队列,直接发送*/
    }
    
    /*释放内存*/
    free(packet);
    return 1;
}

- (void)sendVidepData:(NSData *)data{
    int type;//is keyframe or not
    RTMPPacket *packet;
    uint8_t *body;
    
    const char *buf = data.bytes;
    uint32_t len = (uint32_t)data.length;

    /*---去掉帧界定符---*/
    if(buf[2] == 0x00){/* 00 00 00 01*/
        buf += 4;
        len -= 4;
    }else if (buf[0] == 0x01){/* 00 00 01*/
        buf += 3;
        len -= 3;
    }

    type = buf[0] & 0x1f;
    packet = (RTMPPacket *)malloc(RTMP_MAX_HEADER_SIZE + len + 9);
    packet->m_body = (char *)packet + RTMP_MAX_HEADER_SIZE;
    packet->m_nBodySize = len + 9;
    body = (uint8_t *)packet->m_body;
    
    /*---send video packet-*/
    memset(body, 0, len + 9);
    if(type == NAL_SLICE_IDR){//0001 1001
        body[0] = 0x17;
    }else{
        body[0] = 0x27;//0001 1001
    }
    /**---nal unit---*/
    body[1] = 0x01;
    body[2] = 0x00;
    body[3] = 0x00;
    body[4] = 0x00;
    
    body[5] = (len >> 24) & 0xff;
    body[6] = (len >> 16) & 0xff;
    body[7] = (len >> 8) & 0xff;
    body[8] = len & 0xff;
    
    //data
    memcpy(&body[9], buf, len);
    
    
    packet->m_hasAbsTimestamp = 0;
    packet->m_nTimeStamp = (uint32_t)self.currentTimestamp;
    packet->m_nBodySize = len + 9;
    packet->m_packetType = RTMP_PACKET_TYPE_VIDEO; /*此处为类型有两种一种是音频,一种是视频*/
    packet->m_nInfoField2 = rtmp->m_stream_id;
    packet->m_nChannel = 0x04;
    packet->m_headerType = RTMP_PACKET_SIZE_LARGE;
    
    
    /*发送*/
    if (RTMP_IsConnected(rtmp)) {
        RTMP_SendPacket(rtmp,packet,TRUE); /*TRUE为放进发送队列,FALSE是不放进发送队列,直接发送*/
    }
    
    /*释放内存*/
    free(packet);
 
}

@end
