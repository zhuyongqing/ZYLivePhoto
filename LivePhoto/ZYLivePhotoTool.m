//
//  ZYLivePhotoTool.m
//  LivePhoto
//
//  Created by zhuyongqing on 2018/4/26.
//  Copyright © 2018年 zhuyongqing. All rights reserved.
//

#import "ZYLivePhotoTool.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

static NSString * const kFigAppleMakerNote_AssetIdentifier = @"17";
static NSString * const kKeyContentIdentifier =  @"com.apple.quicktime.content.identifier";
static NSString * const kKeyStillImageTime = @"com.apple.quicktime.still-image-time";
static NSString * const kKeySpaceQuickTimeMetadata = @"mdta";

static ZYLivePhotoTool *tool = nil;

@implementation ZYLivePhotoTool

+ (instancetype)shareTool{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tool = [[ZYLivePhotoTool alloc] init];
    });
    return tool;
}

- (void)generatorLivePhotoWithAsset:(AVAsset *)asset
                      originImgPath:(NSString *)originImgPath
                   livePhotoImgPath:(NSString *)imgPath
                 livePhotoVideoPath:(NSString *)videoPath
                    handleLivePhoto:(void (^)(PHLivePhoto *))handle{
    
    NSString *assetID = [NSUUID UUID].UUIDString;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self dealImageWithOriginPath:originImgPath filePath:imgPath assetIdentifier:assetID];
        [self dealVideoWithWriteFilePath:videoPath AssetIdentifier:assetID asset:asset];
        dispatch_async(dispatch_get_main_queue(), ^{
           AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
            [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[[NSURL fileURLWithPath:videoPath],[NSURL fileURLWithPath:imgPath]] placeholderImage:nil targetSize:track.naturalSize contentMode:PHImageContentModeAspectFit resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nonnull info) {
                handle(livePhoto);
            }];
        });
    });
}

- (void)generatorOriginImgWithAsset:(AVAsset *)asset
                            seconds:(NSTimeInterval)seconds
                          imageName:(NSString *)imgName
                          handleImg:(void(^)(UIImage *originImage,NSString *imagePath,NSError *error))handle{
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = true;
    generator.maximumSize = track.naturalSize;
    CGImageRef image = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(seconds, asset.duration.timescale) actualTime:nil error:nil];
    if (image != nil) {
        NSData *data = UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
        NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *url = urls[0];
        NSString *imageURL = [url.path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",imgName]];
        [data writeToFile:imageURL atomically:true];
        handle([UIImage imageWithCGImage:image],imageURL,nil);
        CGImageRelease(image);
    }
}

- (AVAsset *)cutVideoWithPath:(NSString *)videoPath startTime:(NSTimeInterval)start endTime:(NSTimeInterval)end{
     AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    AVMutableComposition *composition = [[AVMutableComposition alloc] init];
    AVMutableCompositionTrack *muTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVAssetTrack *originTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetTrack *originAudioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    
    [muTrack insertTimeRange:CMTimeRangeMake(CMTimeMakeWithSeconds(start, asset.duration.timescale), CMTimeMakeWithSeconds(end, asset.duration.timescale)) ofTrack:originTrack atTime:kCMTimeZero error:nil];
    [audioTrack insertTimeRange:CMTimeRangeMake(CMTimeMakeWithSeconds(start, asset.duration.timescale), CMTimeMakeWithSeconds(end, asset.duration.timescale)) ofTrack:originAudioTrack atTime:kCMTimeZero error:nil];
    muTrack.preferredTransform = originTrack.preferredTransform;
    
    return composition;
}

- (void)dealImageWithOriginPath:(NSString *)originPath
                 filePath:(NSString *)finalPath
                     assetIdentifier:(NSString *)assetIdentifier {
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((CFURLRef)[NSURL fileURLWithPath:finalPath], kUTTypeJPEG, 1, nil);
    CGImageSourceRef imageSourceRef = CGImageSourceCreateWithData((CFDataRef)[NSData dataWithContentsOfFile:originPath], nil);
    NSMutableDictionary *metaData = [(__bridge_transfer  NSDictionary*)CGImageSourceCopyPropertiesAtIndex(imageSourceRef, 0, nil) mutableCopy];
    
    NSMutableDictionary *makerNote = [NSMutableDictionary dictionary];
    [makerNote setValue:assetIdentifier forKey:kFigAppleMakerNote_AssetIdentifier];
    [metaData setValue:makerNote forKey:(__bridge_transfer  NSString*)kCGImagePropertyMakerAppleDictionary];
    CGImageDestinationAddImageFromSource(dest, imageSourceRef, 0, (CFDictionaryRef)metaData);
    CGImageDestinationFinalize(dest);
    CFRelease(dest);
}

- (void)dealVideoWithWriteFilePath:(NSString *)finalMovPath
                     AssetIdentifier:(NSString *)assetIdentifier
                               asset:(AVAsset *)asset{
    
    AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetTrack *audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    
    if (!videoTrack) {
        return;
    }
    
    AVAssetReaderOutput *videoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:@{(__bridge_transfer  NSString*)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]}];
    
    NSDictionary *audioDic = @{AVFormatIDKey :@(kAudioFormatLinearPCM),
                               AVLinearPCMIsBigEndianKey:@NO,
                               AVLinearPCMIsFloatKey:@NO,
                               AVLinearPCMBitDepthKey :@(16)
                               };
    
    NSError *error;
    
    
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
    if([reader canAddOutput:videoOutput]) {
        [reader addOutput:videoOutput];
    } else {
        NSLog(@"Add video output error\n");
    }
    
    AVAssetReaderTrackOutput *audioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:audioDic];
    
    if([reader canAddOutput:audioOutput]) {
        [reader addOutput:audioOutput];
    } else {
        NSLog(@"Add audio output error\n");
    }
    
    NSDictionary * outputSetting = @{AVVideoCodecKey: AVVideoCodecH264,
                                     AVVideoWidthKey: [NSNumber numberWithFloat:videoTrack.naturalSize.width],
                                     AVVideoHeightKey: [NSNumber numberWithFloat:videoTrack.naturalSize.height]
                                     };
    
    AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSetting];
    videoInput.expectsMediaDataInRealTime = true;
    videoInput.transform = videoTrack.preferredTransform;
    
    NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                   [ NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                                   [ NSNumber numberWithFloat: 44100], AVSampleRateKey,
                                   [ NSNumber numberWithInt: 128000], AVEncoderBitRateKey,
                                   nil];
    
    AVAssetWriterInput *audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:[audioTrack mediaType] outputSettings:audioSettings];
    audioInput.expectsMediaDataInRealTime = true;
    audioInput.transform = audioTrack.preferredTransform;
    
    NSError *error_two;
    
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:finalMovPath] fileType:AVFileTypeQuickTimeMovie error:&error_two];
    if(error_two) {
        NSLog(@"CreateWriterError:%@\n",error_two);
    }
    writer.metadata = @[ [self metaDataSet:assetIdentifier]];
    [writer addInput:videoInput];
    [writer addInput:audioInput];
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
                                                           kCVPixelBufferPixelFormatTypeKey, nil];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    AVAssetWriterInputMetadataAdaptor *adapter = [self metadataSetAdapter];
    [writer addInput:adapter.assetWriterInput];
    [writer startWriting];
    [reader startReading];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    CMTimeRange dummyTimeRange = CMTimeRangeMake(CMTimeMake(0, 1000), CMTimeMake(200, 3000));
    //Meta data reset:
    AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
    item.key = kKeyStillImageTime;
    item.keySpace = kKeySpaceQuickTimeMetadata;
    item.value = [NSNumber numberWithInt:0];
    item.dataType = @"com.apple.metadata.datatype.int8";
    [adapter appendTimedMetadataGroup:[[AVTimedMetadataGroup alloc] initWithItems:[NSArray arrayWithObject:item] timeRange:dummyTimeRange]];
    
    
    dispatch_queue_t createMovQueue = dispatch_queue_create("createMovQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(createMovQueue, ^{
        while (reader.status == AVAssetReaderStatusReading) {
            CMSampleBufferRef videoBuffer = [videoOutput copyNextSampleBuffer];
            CMSampleBufferRef audioBuffer = [audioOutput copyNextSampleBuffer];
            
            if (videoBuffer) {
                while (!videoInput.isReadyForMoreMediaData || !audioInput.isReadyForMoreMediaData) {
                    usleep(1);
                }
                
                if (audioBuffer) {
                    [audioInput appendSampleBuffer:audioBuffer];
                    CFRelease(audioBuffer);
                }

                [adaptor.assetWriterInput appendSampleBuffer:videoBuffer];
                CMSampleBufferInvalidate(videoBuffer);
                CFRelease(videoBuffer);
                videoBuffer = nil;
                
            } else {
                continue;
            }
            // NULL?
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            [writer finishWritingWithCompletionHandler:^{
                NSLog(@"Finish \n");
            }];
        });
    });
    
    
    while (writer.status == AVAssetWriterStatusWriting) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    }
}

- (AVAssetWriterInputMetadataAdaptor *)metadataSetAdapter {
    NSString *identifier = [kKeySpaceQuickTimeMetadata stringByAppendingFormat:@"/%@",kKeyStillImageTime];
    const NSDictionary *spec = @{(__bridge_transfer  NSString*)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier :
                                     identifier,
                                 (__bridge_transfer  NSString*)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType :
                                     @"com.apple.metadata.datatype.int8"
                                 };
    CMFormatDescriptionRef desc;
    CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, (__bridge CFArrayRef)@[spec], &desc);
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:desc];
    CFRelease(desc);
    return [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:input];
    
}

- (AVMetadataItem *)metaDataSet:(NSString *)assetIdentifier {
    AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
    item.key = kKeyContentIdentifier;
    item.keySpace = kKeySpaceQuickTimeMetadata;
    item.value = assetIdentifier;
    item.dataType = @"com.apple.metadata.datatype.UTF-8";
    return item;
}

- (void)saveLivePhotoWithVideoPath:(NSString *)videoPath imagePath:(NSString *)imagePath handle:(void(^)(BOOL,NSError *))saveHandle{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
        PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
        
        [creationRequest addResourceWithType:PHAssetResourceTypePairedVideo fileURL:[NSURL fileURLWithPath:videoPath] options:options];
        [creationRequest addResourceWithType:PHAssetResourceTypePhoto fileURL:[NSURL fileURLWithPath:imagePath] options:options];
        
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        saveHandle(success,error);
    }];
}


@end
