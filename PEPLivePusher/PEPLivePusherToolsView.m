//
//  PEPLivePusherToolsView.m
//  LivePusher
//
//  Created by 李沛倬 on 2019/7/22.
//  Copyright © 2019 pep. All rights reserved.
//

#import "PEPLivePusherToolsView.h"
#import "PEPLivePusherUtility.h"


@interface PEPLivePusherInfoLabel : UILabel

@end

@implementation PEPLivePusherInfoLabel

- (void)drawTextInRect:(CGRect)rect {
    NSLog(@"%@", NSStringFromCGRect(rect));
    
    UIEdgeInsets insets = UIEdgeInsetsMake(-8, -8, -8, -8);
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}

@end





@interface PEPLivePusherToolsView ()

@property (nonatomic, assign, readonly) UIEdgeInsets safeAreaInsets;

@property (nonatomic, strong) AlivcLivePushConfig *pushConfig;

@property (nonatomic, strong) PEPLivePusherInfoLabel *infoLabel;

@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) UIButton *startPushButton;

@property (nonatomic, strong) UIButton *reconnectButton;

@end

@implementation PEPLivePusherToolsView

// MARK: - Life Cycle

- (instancetype)initWithFrame:(CGRect)frame config:(AlivcLivePushConfig *)config {
    if (self = [super initWithFrame:frame]) {
        self.pushConfig = config;
        
        [self initSubviews];
    }
    
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initSubviews];
    }
    return self;
}


// MARK: - Public Method

- (void)updateInfoText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.infoLabel.text = text;
        [UIView animateWithDuration:0.25 animations:^{
            self.infoLabel.alpha = 1;
        }];
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(hiddenInfoLabel) withObject:nil afterDelay:2.0];
    });
}

- (void)hiddenInfoLabel {
    [UIView animateWithDuration:0.25 animations:^{
        self.infoLabel.alpha = 0;
    }];
}

// MARK: - Action

- (void)closeButtonAction:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(toolBarOnClickedBackButton:)]) {
        [self.delegate toolBarOnClickedBackButton:sender];
    }
}

- (void)startPushButtonAction:(UIButton *)sender {
    sender.selected = !sender.selected;
    
    if ([self.delegate respondsToSelector:@selector(toolBarOnClickedStartPushButton:)]) {
        BOOL started = [self.delegate toolBarOnClickedStartPushButton:sender];
        
        sender.selected = started;
    }
}

- (void)reconnectButtonAction:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(toolBarOnClickedReconnectPushButton:)]) {
        [self.delegate toolBarOnClickedReconnectPushButton:sender];
    }
}



// MARK: - UI

- (void)initSubviews {
#ifdef DEBUG
    PEPLivePusherInfoLabel *infoLabel = [PEPLivePusherInfoLabel.alloc init];
    infoLabel.frame = CGRectMake(20, 100, self.bounds.size.width - 40, 40);
    infoLabel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    infoLabel.layer.masksToBounds = true;
    infoLabel.layer.cornerRadius = 10;
    infoLabel.alpha = 0;
    
    [self addSubview:infoLabel];
    
    self.infoLabel = infoLabel;
#endif
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(CGRectGetWidth(self.bounds)-30-40, self.safeAreaInsets.top+10, 40, 40);
    [closeButton setImage:ImageNamedFromPEPLivePusherBundle(@"close") forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *startPushButton = [UIButton buttonWithType:UIButtonTypeCustom];
    startPushButton.frame = CGRectMake(self.center.x-67/2.0, CGRectGetHeight(self.bounds)-67-(self.safeAreaInsets.bottom ? : 26), 67, 67);
    [startPushButton setImage:ImageNamedFromPEPLivePusherBundle(@"record") forState:UIControlStateNormal];
    [startPushButton setImage:ImageNamedFromPEPLivePusherBundle(@"stop") forState:UIControlStateSelected];
    [startPushButton addTarget:self action:@selector(startPushButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *reconnectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    reconnectButton.frame = CGRectMake(CGRectGetMaxX(startPushButton.frame)+50, CGRectGetHeight(self.bounds)-40-(self.safeAreaInsets.bottom ? : 26)-13.5, 40, 40);
    [reconnectButton setImage:ImageNamedFromPEPLivePusherBundle(@"change") forState:UIControlStateNormal];
    [reconnectButton addTarget:self action:@selector(reconnectButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    
    [self addSubview:closeButton];
    [self addSubview:startPushButton];
    [self addSubview:reconnectButton];
    
    
    self.closeButton = closeButton;
    self.startPushButton = startPushButton;
    self.reconnectButton = reconnectButton;
}


- (UIEdgeInsets)safeAreaInsets {
    if (@available(iOS 11.0, *)) {
        return UIApplication.sharedApplication.keyWindow.safeAreaInsets;
    } else {
        return UIEdgeInsetsZero;
    }
}

@end
