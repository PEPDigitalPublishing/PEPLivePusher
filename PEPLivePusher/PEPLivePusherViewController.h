//
//  PEPLivePusherViewController.h
//  LivePusher
//
//  Created by 李沛倬 on 2019/7/22.
//  Copyright © 2019 pep. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 推流类型

 - PEPLivePusherLive: 直播。默认类型
 - PEPLivePusherVideo: 视频
 */
typedef NS_ENUM(NSUInteger, PEPLivePusherType) {
    PEPLivePusherLive,
    PEPLivePusherVideo,
};

typedef NS_ENUM(NSUInteger, PEPLivePusherPushState) {
    PEPLivePusherPushStateUnknow,
    PEPLivePusherPushStateStartPreview,
    PEPLivePusherPushStateStopPreview,
    PEPLivePusherPushStatePushing,
    PEPLivePusherPushStatePause,
    PEPLivePusherPushStateStop,
    PEPLivePusherPushStateRepush,
    PEPLivePusherPushStateDestory,
    PEPLivePusherPushStateError,
};

typedef NS_ENUM(NSUInteger, PEPOrientation) {
    PEPOrientationLeft = 0,
    PEPOrientationRight,
};

#define NOTIFICATION_NAME @"screenOrientation"

@protocol PEPLivePusherViewControllerDelegate;
/**
 debug模式会在屏幕上方显示调试信息，控制台也会打印大量调试内容。release模式会自动屏蔽掉这些输出
 */
@interface PEPLivePusherViewController : UIViewController

/// 推流地址
@property (nonatomic, strong) NSString *pushURL;

/// 是否使用异步接口
@property (nonatomic, assign) BOOL isUseAsyncInterface;

/// 推流类型。默认为直播类型
@property (nonatomic, assign) PEPLivePusherType pusherType;

@property (nonatomic, weak) id<PEPLivePusherViewControllerDelegate> delegate;


@property (nonatomic, copy) NSString *authDuration      DEPRECATED_ATTRIBUTE;

@property (nonatomic, copy) NSString *authKey           DEPRECATED_ATTRIBUTE;



@end

@protocol PEPLivePusherViewControllerDelegate <NSObject>

- (void)livePusherViewController:(PEPLivePusherViewController *)livePusher pushStateChanged:(PEPLivePusherPushState)pushState;

- (void)getNotificationOrientation:(NSInteger)orientation;

@end

NS_ASSUME_NONNULL_END
