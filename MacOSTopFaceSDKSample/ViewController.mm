//
//  ViewController.m
//
//
//  Created by Jeavil on 17/2/4.
//  Copyright © 2017年 topplus. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>

#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

#import "opencv2/opencv.hpp"


#import <MacOSTopFaceSDK/MacOSTopFaceSDKHandle.h>

@interface ViewController()<AVCaptureVideoDataOutputSampleBufferDelegate>{
    
    MacOSTopFaceSDKHandle *handle;
}

@property (weak) IBOutlet NSImageView *testImage;

@property (nonatomic, strong)AVCaptureSession *captureSession;

@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据

@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层
@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self initDetector];
    [self configCamera];
}

- (void)viewWillAppear{
    [_captureSession startRunning];
}

- (void)initDetector{
    handle = [[MacOSTopFaceSDKHandle alloc]init];
    //[handle setLicense:@"您的client_id" andSecret:@"您的client_secret"];
    NSLog(@"status = %d",[handle Engine_InitWithFocus:31]);
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}


- (void)configCamera{
    
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPreset1280x720;
        
    }
    
    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    if (!captureDevice) {
        NSLog(@"取得后置摄像头时出现问题.");
        return;
    }
    //添加一个音频输入设备
    //AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    //AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        // [_captureSession addInput:audioCaptureDeviceInput];
    }
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc]init];
    //配置output对象
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    if ([_captureSession canAddOutput:output]) {
        [_captureSession addOutput:output];
    }
    
    
}

#pragma mark - 私有方法

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];

    return cameras[0];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    //
    //        // Get the pixel buffer width and heigh
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    NSLog(@"width=%zu,height=%zu",width,height);
    
    cv::Mat mat((int)height, (int)width, CV_8UC4, baseAddress, 0);
    cv::Mat transfMat;
    cv::transpose(mat, transfMat);
    cv::Mat RGBimage,grayImage;
    cv::cvtColor(mat, RGBimage, CV_BGR2RGB);
    //cv::cvtColor(RGBimage, grayImage, CV_RGB2GRAY);
    cv::resize(RGBimage, RGBimage, cvSize(RGBimage.cols * 0.5, RGBimage.rows * 0.5));
    cv::flip(RGBimage, RGBimage, 1);
    double vpose[6];
    
    std::vector<cv::Point2f> tempPoints;
    NSArray *data = [handle DynamicDetect:sampleBuffer];
    //
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    if (data.count > 144) {
        for (int i = 0; i < 68; i++)
        {//miao dian
            cv::Point2f tempPoint;
            tempPoint.x = [data[i * 2] doubleValue];
            
            tempPoint.y = [data[(i * 2) + 1] doubleValue];
            
            cv::circle(RGBimage, tempPoint, 2, cv::Scalar(0,255,0),-1);
            
        }
        cv::Point2f tempPoint1,tempPoint2,tempPoint3,tempPoint4;
        tempPoint1.x = [data[143] doubleValue];
        tempPoint1.y = [data[144] doubleValue];
        tempPoint2.x = [data[145] doubleValue];
        tempPoint2.y = [data[146] doubleValue];
        tempPoint3.x = [data[147] doubleValue];
        tempPoint3.y = [data[148] doubleValue];
        tempPoint4.x = [data[149] doubleValue];
        tempPoint4.y = [data[150] doubleValue];
        
        
        cv::line(RGBimage, tempPoint1, tempPoint1, cv::Scalar(0, 0, 255), 2);
        cv::line(RGBimage, tempPoint1, tempPoint2, cv::Scalar(0, 255, 0), 2);
        cv::line(RGBimage, tempPoint1, tempPoint3, cv::Scalar(0, 0, 255), 2);
        cv::line(RGBimage, tempPoint1, tempPoint4, cv::Scalar(255, 0, 0), 2);
        
    }
    
    NSLog(@"%d %d",RGBimage.rows,RGBimage.cols);
    NSImage *tempImage = [self UIImageFromCVMat:RGBimage];
    dispatch_async(dispatch_get_main_queue(), ^{
        _testImage.image = tempImage;
    });
    
}

- (NSImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    NSImage *finalImage = [[NSImage alloc]initWithCGImage:imageRef size:CGSizeMake(cvMat.cols, cvMat.rows)];;
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}
@end
