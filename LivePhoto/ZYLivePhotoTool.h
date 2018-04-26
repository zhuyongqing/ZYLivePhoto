//
//  ZYLivePhotoTool.h
//  LivePhoto
//
//  Created by zhuyongqing on 2018/4/26.
//  Copyright © 2018年 zhuyongqing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface ZYLivePhotoTool : NSObject

+ (instancetype)shareTool;

- (AVAsset *)cutVideoWithPath:(NSString *)videoPath startTime:(NSTimeInterval)start endTime:(NSTimeInterval)end;

- (void)generatorLivePhotoWithAsset:(AVAsset *)asset
                      originImgPath:(NSString *)originImgPath
                   livePhotoImgPath:(NSString *)imgPath
                 livePhotoVideoPath:(NSString *)videoPath
                    handleLivePhoto:(void(^)(PHLivePhoto *livePhoto))handle;

- (void)generatorOriginImgWithAsset:(AVAsset *)asset
                            seconds:(NSTimeInterval)seconds
                          imageName:(NSString *)imgName
                          handleImg:(void(^)(UIImage *originImage,NSString *imagePath,NSError *error))handle;

- (void)saveLivePhotoWithVideoPath:(NSString *)videoPath imagePath:(NSString *)imagePath;



@end
