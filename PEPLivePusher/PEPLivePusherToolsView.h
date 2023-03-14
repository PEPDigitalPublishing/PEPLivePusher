//
//  PEPLivePusherToolsView.h
//  LivePusher
//
//  Created by 李沛倬 on 2019/7/22.
//  Copyright © 2019 pep. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AlivcLivePusher/AlivcLivePushConfig.h>

@protocol PEPLivePusherToolsViewDelegate <NSObject>

- (void)toolBarOnClickedBackButton:(UIButton *_Nullable)sender;

- (BOOL)toolBarOnClickedStartPushButton:(UIButton *_Nullable)sender;

- (void)toolBarOnClickedReconnectPushButton:(UIButton *_Nullable)sender;

@end

NS_ASSUME_NONNULL_BEGIN

@interface PEPLivePusherToolsView : UIView

@property (nonatomic, weak) id<PEPLivePusherToolsViewDelegate> delegate;

@property (nonatomic, strong, readonly) UIButton *startPushButton;


- (instancetype)initWithFrame:(CGRect)frame config:(AlivcLivePushConfig *)config;

- (void)updateInfoText:(NSString *)text;


@end

NS_ASSUME_NONNULL_END
