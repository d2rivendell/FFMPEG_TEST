//
//  H264Manager.m
//  FFMPEG_TEST
//
//  Created by hyf on 16/8/6.
//  Copyright © 2016年 FanHwa. All rights reserved.
//

#import "H264Manager.h"


@interface H264Manager()<X264ManagerDelegate>
{
    FILE *fp;
}
@property(nonatomic,assign)EncoderType  type;
@property(nonatomic,assign)int  width;
@property(nonatomic,assign)int  height;
@property(nonatomic,copy)NSString *fileName;
@end
@implementation H264Manager

- (instancetype)initWithEncodeType:(EncoderType)type  width:(int)width height:(int)height fileName:(NSString *)fileName;
{
    self = [super init];
    if (self) {
        _type = type;
        _width = width;
        _height = height;
        _fileName = fileName;
        [self initForFilePathWithName:@"new.h264"];
    }
    return self;
}

- (id<FANSoftEncoderDelegate>)encoder{
    if(_encoder == nil){
      if(_type == X264Encoder){
        X264Manager  *_x264 = [[X264Manager alloc] initWithWidth:self.width height:self.height  fileName:self.fileName];
          _x264.delegate = self;
          _encoder = _x264;
          
      }else{
          _encoder = [[FFMPEG264Manager alloc] initWithWidth:self.width  height:self.height  fileName:self.fileName];
      }
    }
    return _encoder;
}

- (void)X264Manager:(X264Manager *)manager didEncoderh264Data:(NSData *)h264data{
    //fwrite(h264data.bytes, 1, h264data.length, fp);
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
