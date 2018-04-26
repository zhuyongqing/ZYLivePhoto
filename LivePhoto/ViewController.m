//
//  ViewController.m
//  LivePhoto
//
//  Created by zhuyongqing on 2018/4/26.
//  Copyright © 2018年 zhuyongqing. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ZYLivePhotoTool.h"
#import <PhotosUI/PhotosUI.h>

@interface ViewController ()


@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    PHLivePhotoView *photoView = [[PHLivePhotoView alloc] initWithFrame:CGRectMake(0, 200, CGRectGetWidth(self.view.frame), 300)];
    [self.view addSubview:photoView];
    
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"IMG_0021" ofType:@"MP4"];
    
    AVAsset *asset = [[ZYLivePhotoTool shareTool] cutVideoWithPath:videoPath startTime:2.0 endTime:5.0];
    
    [[ZYLivePhotoTool shareTool] generatorOriginImgWithAsset:asset seconds:2.0 imageName:@"image" handleImg:^(UIImage *originImage, NSString *imagePath, NSError *error) {
        NSString *outPut = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true).firstObject;
        NSString *newImgPath = [outPut stringByAppendingPathComponent:@"IMG.JPG"];
        NSString *newVideoPath = [outPut stringByAppendingPathComponent:@"IMG.MOV"];
        [[NSFileManager defaultManager] removeItemAtPath:newImgPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:newVideoPath error:nil];
        
        [[ZYLivePhotoTool shareTool] generatorLivePhotoWithAsset:asset originImgPath:imagePath livePhotoImgPath:newImgPath livePhotoVideoPath:newVideoPath handleLivePhoto:^(PHLivePhoto *livePhoto) {
            photoView.livePhoto = livePhoto;
            
//            [[ZYLivePhotoTool shareTool] saveLivePhotoWithVideoPath:newVideoPath imagePath:newImgPath handle:^(BOOL success, NSError *error) {
//                
//            }];
        }];
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
