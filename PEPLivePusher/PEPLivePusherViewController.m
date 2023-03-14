//
//  PEPLivePusherViewController.m
//  LivePusher
//
//  Created by 李沛倬 on 2019/7/22.
//  Copyright © 2019 pep. All rights reserved.
//

#import "PEPLivePusherViewController.h"
#import "PEPLivePusherToolsView.h"
#import "PEPLivePusherUtility.h"


#import <CommonCrypto/CommonDigest.h>
#include <sys/time.h>

#import <AlivcLivePusher/AlivcLivePusher.h>


#define kAlivcLivePusherVCAlertTag 89976
#define kAlivcLivePusherNoticeTimerInterval 5.0

#define TEST_EXTERN_YUV_BUFFER_SIZE 1280*720*3/2
#define TEST_EXTERN_PCM_BUFFER_SIZE 3200

#define TEST_EXTERN_YUV_DURATION 40000
#define TEST_EXTERN_PCM_DURATION 30000


@interface PEPLivePusherViewController ()<PEPLivePusherToolsViewDelegate, AlivcLivePusherInfoDelegate, AlivcLivePusherErrorDelegate, AlivcLivePusherNetworkDelegate>
{
    dispatch_source_t _streamingTimer;
    int _userVideoStreamHandle;
    int _userAudioStreamHandle;
    FILE*  _videoStreamFp;
    FILE*  _audioStreamFp;
    int64_t _lastVideoPTS;
    int64_t _lastAudioPTS;
    char yuvData[TEST_EXTERN_YUV_BUFFER_SIZE];
    char pcmData[TEST_EXTERN_PCM_BUFFER_SIZE];
//    AlivcLivePushResolution defaultRes;
//    int defaultChannel;
//    AlivcLivePushAudioSampleRate defaultSampleRate;
    
    BOOL _navigationBarHiddenState;
}

@property (nonatomic, assign, readonly) UIEdgeInsets safeAreaInsets;

@property (nonatomic, strong) AlivcLivePushConfig *pushConfig;

@property (nonatomic, strong) AlivcLivePusher *livePusher;

@property (nonatomic, strong) PEPLivePusherToolsView *toolsView;

@property (nonatomic, strong) UIView *previewView;

@property (nonatomic, weak) NSTimer *noticeTimer;


@property (nonatomic, assign) BOOL onViewDidLoaded;


@property (nonatomic, assign) PEPLivePusherPushState pushState;

//@property(nonatomic,assign)BOOL is_pause;/**<  是否暂停*/
@end

int64_t getCurrentTimeUs() {
    uint64_t succ;
    struct timeval time;
    gettimeofday(&time, NULL);
    succ = time.tv_sec * 1000000ll + (time.tv_usec);
    
    return succ;
}

@implementation PEPLivePusherViewController

// MARK: - Life Cycle

- (void)dealloc {
    NSLog(@"%s", __FUNCTION__);
    NSLog(@"释放了");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addBackgroundNotifications];
    [self initSubviews];
    
#ifdef DEBUG
    [self setupDebugTimer];
#endif
    
    BOOL succ = [self setupPusher];
    if (succ == false) {
        [self showPusherInitErrorAlert:succ];
        return;
    }

    succ = [self startPreview];
    if (succ == false) {
        [self showPusherStartPreviewErrorAlert:succ isStart:true];
        return;
    }

    self.onViewDidLoaded = true;
    UIApplication.sharedApplication.idleTimerDisabled = true;
    //添加通知
    [self addNotification];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.navigationController) {
        _navigationBarHiddenState = self.navigationController.navigationBarHidden;
        [self.navigationController setNavigationBarHidden:true animated:true];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.onViewDidLoaded == true) {
        BOOL succ = [self startPush];
        if (succ == false) {
            [self showPusherStartPushErrorAlert:succ isStart:true];
            return;
        }
        self.toolsView.startPushButton.selected = succ;
        self.onViewDidLoaded = false;
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    //销毁通知
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:_navigationBarHiddenState animated:true];
    }
}

// MARK: - Notifation
- (void)addNotification{
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDeviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)handleDeviceOrientationDidChange:(UIInterfaceOrientation)interfaceOrientation
{
    UIDevice *device = [UIDevice currentDevice] ;
    switch (device.orientation) {
        case UIDeviceOrientationFaceUp:
            NSLog(@"屏幕朝上平躺");
            break;
        case UIDeviceOrientationFaceDown:
            NSLog(@"屏幕朝下平躺");
            break;
        case UIDeviceOrientationUnknown:
            NSLog(@"未知方向");
            break;
        case UIDeviceOrientationLandscapeLeft:
            NSLog(@"屏幕向左横置");
            [self.delegate getNotificationOrientation:PEPOrientationLeft];
            break;
        case UIDeviceOrientationLandscapeRight:
            NSLog(@"屏幕向右橫置");
            [self.delegate getNotificationOrientation:PEPOrientationRight];
            break;
        case UIDeviceOrientationPortrait:
            NSLog(@"屏幕直立");
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            NSLog(@"屏幕直立，上下顛倒");
            break;
        default:
            NSLog(@"无法辨识");
            break;
    }
    //返回设备方向
//    [self.delegate getNotificationOrientation:interfaceOrientation];
}

// MARK: - Action

- (void)addUserStream {
    if(self.pusherType != PEPLivePusherVideo) { return; }
    
    if (_streamingTimer) { return; }
    
    _videoStreamFp = 0;
    _audioStreamFp = 0;
    _lastVideoPTS = 0;
    _lastAudioPTS = 0;
    
    __weak typeof(self) weakself = self;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _streamingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_streamingTimer,DISPATCH_TIME_NOW, 10*NSEC_PER_MSEC, 0);
    dispatch_source_set_event_handler(_streamingTimer, ^{
        
        [weakself streamingTimerAction];
    });
    
    dispatch_resume(_streamingTimer);
}


- (void)streamingTimerAction {
    
    if (!_videoStreamFp) {
        NSString *userVideoPath = [NSBundle.mainBundle pathForResource:@"capture" ofType:@"yuv"];
        const char *video_path = [userVideoPath UTF8String];
        _videoStreamFp = fopen(video_path, "rb");
    }
    
    if (!_audioStreamFp) {
        NSString *userAudioPath = [NSBundle.mainBundle pathForResource:@"441" ofType:@"pcm"];
        const char *audio_path = [userAudioPath UTF8String];
        _audioStreamFp = fopen(audio_path, "rb");
    }
    
    if (_videoStreamFp) {
        
        int64_t nowTime = getCurrentTimeUs();
        if (nowTime - _lastVideoPTS >= TEST_EXTERN_YUV_DURATION) {
            
            int dataSize = TEST_EXTERN_YUV_BUFFER_SIZE;
            size_t size = fread((void *)yuvData, 1, dataSize, _videoStreamFp);
            if (size < dataSize) {
                fseek(_videoStreamFp, 0, SEEK_SET);
                size = fread((void *)yuvData, 1, dataSize, _videoStreamFp);
            }
            
            if (size == dataSize) {
                if (self.pusherType == PEPLivePusherVideo) {
                    [self.livePusher sendVideoData:yuvData width:720 height:1280 size:dataSize pts:nowTime rotation:0];
                }
            }
            _lastVideoPTS = nowTime;
        }
    }
    
    if (_audioStreamFp) {
        int64_t nowTime = getCurrentTimeUs();
        
        if (nowTime - _lastAudioPTS >= TEST_EXTERN_PCM_DURATION) {
            
            int dataSize = TEST_EXTERN_PCM_BUFFER_SIZE;
            size_t size = fread((void *)pcmData, 1, dataSize,  _audioStreamFp);
            
            if (size < dataSize) {
                fseek(_audioStreamFp, 0, SEEK_SET);
            }
            
            if (size > 0) {
                if (self.pusherType == PEPLivePusherVideo) {
                    [self.livePusher sendPCMData:pcmData size:(int)size sampleRate:44100 channel:1 pts:nowTime];
                }
            }
            _lastAudioPTS = nowTime;
            
        }
    }

}

- (void)setPushState:(PEPLivePusherPushState)pushState {
    if (_pushState != pushState) {
        _pushState = pushState;
        
        if ([self.delegate respondsToSelector:@selector(livePusherViewController:pushStateChanged:)]) {
            [self.delegate livePusherViewController:self pushStateChanged:pushState];
        }
    }
}


// MARK: - 推流


/** 创建推流 */
- (BOOL)setupPusher {
    
    if (self.pusherType == PEPLivePusherVideo) {
        self.pushConfig.externMainStream = true;
        self.pushConfig.externVideoFormat = AlivcLivePushVideoFormatYUVNV12;
    } else {
        self.pushConfig.externMainStream = false;
    }
    
    self.livePusher = [AlivcLivePusher.alloc initWithConfig:self.pushConfig];
    
#ifdef DEBUG
    [self.livePusher setLogLevel:AlivcLivePushLogLevelDebug];
#else
    [self.livePusher setLogLevel:AlivcLivePushLogLevelFatal];
#endif
    
    if (self.livePusher == nil) { return false; }
    
    
    [self.livePusher setInfoDelegate:self];
    [self.livePusher setErrorDelegate:self];
    [self.livePusher setNetworkDelegate:self];
    
    return true;
}

/** 销毁推流 */
- (void)destoryPusher {
    
    if(_streamingTimer) {
        dispatch_cancel(_streamingTimer);
        _streamingTimer = 0;
    }
    
    if(_videoStreamFp) {
        fclose(_videoStreamFp);
        _videoStreamFp = 0;
    }
    
    if(_audioStreamFp) {
        fclose(_audioStreamFp);
        _audioStreamFp = 0;
    }
    
    
    if (self.livePusher) {
        [self.livePusher destory];
    }
    
    
    self.pushState = PEPLivePusherPushStateDestory;
    self.livePusher = nil;
}


/** 开始预览 */
- (BOOL)startPreview {
    BOOL succ = false;
    
    if (!self.livePusher) { return succ; }
    
    if (self.isUseAsyncInterface) {
        // 使用异步接口
        succ = ![self.livePusher startPreviewAsync:self.previewView];
    } else {
        // 使用同步接口
        succ = ![self.livePusher startPreview:self.previewView];
    }
    
    self.pushState = succ ? PEPLivePusherPushStateStartPreview : PEPLivePusherPushStateError;
    return succ;
}


/** 停止预览 */
- (BOOL)stopPreview {
    BOOL succ = false;
    
    if (!self.livePusher) { return succ; }
    
    succ = ![self.livePusher stopPreview];
    
    self.pushState = succ ? PEPLivePusherPushStateStopPreview : PEPLivePusherPushStateError;
    return succ;
}


/** 开始推流 */
- (BOOL)startPush {
    BOOL succ = false;
    
    if (!self.livePusher) { return succ; }
    
    // 鉴权测试时，使用Auth A类型的URL。
//    [self updateAuthURL];
    
    if (self.isUseAsyncInterface) {
        // 使用异步接口
        int ret = [self.livePusher startPushWithURLAsync:self.pushURL];
        succ = !ret;
//        succ = ![self.livePusher startPushWithURLAsync:self.pushURL];
        
    } else {
        // 使用同步接口
        succ = ![self.livePusher startPushWithURL:self.pushURL];
    }
    
    self.pushState = succ ? PEPLivePusherPushStatePushing : PEPLivePusherPushStateError;
    return succ;
}


/** 停止推流 */
- (BOOL)stopPush {
    BOOL succ = false;
    
    if (!self.livePusher) { return succ; }
    
    succ = ![self.livePusher stopPush];
    
    self.pushState = succ ? PEPLivePusherPushStateStop : PEPLivePusherPushStateError;
    return succ;
}


/** 暂停推流 */
- (BOOL)pausePush {
    BOOL succ = false;
    
    if (!self.livePusher) { return succ; }
    
    succ = ![self.livePusher pause];
    
    self.pushState = succ ? PEPLivePusherPushStatePause : PEPLivePusherPushStateError;
    return succ;
}


/** 恢复推流 */
- (BOOL)resumePush {
    BOOL succ = false;
    
    if (!self.livePusher) { return succ; }
    
    if (self.isUseAsyncInterface) {
        // 使用异步接口
        succ = ![self.livePusher resumeAsync];
        
    } else {
        // 使用同步接口
        succ = ![self.livePusher resume];
    }
    
    return succ;
}


/** 重新推流 */
- (BOOL)restartPush {
    BOOL succ = false;
    
    if (!self.livePusher) { return succ; }

    if (self.isUseAsyncInterface) {
        // 使用异步接口
        succ = ![self.livePusher restartPushAsync];
        
    } else {
        // 使用同步接口
        succ = ![self.livePusher restartPush];
    }
    
    self.pushState = succ ? PEPLivePusherPushStateRepush : PEPLivePusherPushStateError;
    return succ;
}


/** 重连推流 */
- (void)reconnectPush {
    if (!self.livePusher) { return; }
    
    [self.livePusher reconnectPushAsync];
}




// MARK: - PEPLivePusherToolsViewDelegate

- (void)toolBarOnClickedBackButton:(UIButton *)sender {
    
    [self cancelTimer];
    [self destoryPusher];
    UIApplication.sharedApplication.idleTimerDisabled = false;
    
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:true];
    } else {
        [self dismissViewControllerAnimated:true completion:nil];
    }
}

- (BOOL)toolBarOnClickedStartPushButton:(UIButton *)sender {
    BOOL pushing = false;
    
    if (sender.selected) {
        // 开始推流
        pushing = [self startPush];
        
        if (pushing == false) {
            [self showPusherStartPushErrorAlert:pushing isStart:true];
        }
    } else {
        // 停止推流
        pushing = [self stopPush];
        
        if (pushing == false) {
            [self showPusherStartPushErrorAlert:pushing isStart:false];
        }
        
        pushing = !pushing;   // 停止失败意为仍在推流中，停止成功意为已停止推流。故stopPush方法的返回值与pushing状态相反
    }
    
    return pushing;
}

- (void)toolBarOnClickedReconnectPushButton:(UIButton *)sender {
    [self.livePusher switchCamera];
    
//    BOOL succ = [self restartPush];
//
//    if (succ == false) {
//        [self showAlertViewWithErrorCode:succ
//                                errorStr:nil
//                                     tag:0
//                                   title:NSLocalizedString(@"dialog_title", nil)
//                                 message:@"Restart Error"
//                                delegate:nil
//                             cancelTitle:NSLocalizedString(@"ok", nil)
//                       otherButtonTitles:nil];
//    }
}


// MARK: - AlivcLivePusherInfoDelegate

- (void)onPreviewStarted:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"start_preview_log")];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self addUserStream];
    });
}

- (void)onPreviewStoped:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"stop_preview_log")];
}

- (void)onPushStarted:(AlivcLivePusher *)pusher {

    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"start_push_log")];
}

- (void)onPushPaused:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"pause_push_log")];
}

- (void)onPushResumed:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"resume_push_log")];
}

- (void)onPushStoped:(AlivcLivePusher *)pusher {
    
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"stop_push_log")];
}

- (void)onFirstFramePreviewed:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"first_frame_log")];
}


- (void)onPushRestart:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"restart_push_log")];
}



// MARK: - AlivcLivePusherErrorDelegate

- (void)onSystemError:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    [self showAlertViewWithErrorCode:error.errorCode
                            errorStr:error.errorDescription
                                 tag:kAlivcLivePusherVCAlertTag+11
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:PEPLivePusherLocalizedString(@"system_error")
                            delegate:self
                         cancelTitle:PEPLivePusherLocalizedString(@"exit")
                   otherButtonTitles:PEPLivePusherLocalizedString(@"ok"),nil];
}


- (void)onSDKError:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    [self showAlertViewWithErrorCode:error.errorCode
                            errorStr:error.errorDescription
                                 tag:kAlivcLivePusherVCAlertTag+12
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:PEPLivePusherLocalizedString(@"sdk_error")
                            delegate:self
                         cancelTitle:PEPLivePusherLocalizedString(@"exit")
                   otherButtonTitles:PEPLivePusherLocalizedString(@"ok"),nil];
}


// MARK: - AlivcLivePusherNetworkDelegate

- (void)onConnectFail:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    [self showAlertViewWithErrorCode:error.errorCode
                            errorStr:error.errorDescription
                                 tag:kAlivcLivePusherVCAlertTag+23
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:PEPLivePusherLocalizedString(@"connect_fail")
                            delegate:self
                         cancelTitle:PEPLivePusherLocalizedString(@"reconnect_button")
                   otherButtonTitles:PEPLivePusherLocalizedString(@"exit"), nil];
    
}

- (void)onSendDataTimeout:(AlivcLivePusher *)pusher {
    [self showAlertViewWithErrorCode:0
                            errorStr:nil
                                 tag:0
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:PEPLivePusherLocalizedString(@"senddata_timeout")
                            delegate:nil
                         cancelTitle:PEPLivePusherLocalizedString(@"ok")
                   otherButtonTitles:nil];
}

- (void)onSendSeiMessage:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"send message")];
}

- (void)onConnectRecovery:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"connectRecovery_log")];
}

- (void)onNetworkPoor:(AlivcLivePusher *)pusher {
    [self showAlertViewWithErrorCode:0 errorStr:nil tag:0 title:PEPLivePusherLocalizedString(@"dialog_title") message:@"当前网速较慢，请检查网络状态" delegate:nil cancelTitle:PEPLivePusherLocalizedString(@"ok") otherButtonTitles:nil];
}

- (void)onReconnectStart:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"reconnect_start")];
}

- (void)onReconnectSuccess:(AlivcLivePusher *)pusher {
    [self.toolsView updateInfoText:PEPLivePusherLocalizedString(@"reconnect_success")];
}

- (void)onConnectionLost:(AlivcLivePusher *)pusher {
    
}

- (void)onReconnectError:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    [self showAlertViewWithErrorCode:error.errorCode
                            errorStr:error.errorDescription
                                 tag:kAlivcLivePusherVCAlertTag+22
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:PEPLivePusherLocalizedString(@"reconnect_fail")
                            delegate:self
                         cancelTitle:PEPLivePusherLocalizedString(@"reconnect_button")
                   otherButtonTitles:PEPLivePusherLocalizedString(@"ok"), nil];
}

- (NSString *)onPushURLAuthenticationOverdue:(AlivcLivePusher *)pusher {
    // FIXME: - 鉴权即将过期
    
//    [self.toolsView updateInfoText:@"Auth push url update"];
//
//    if(!self.livePusher.isPushing) {
//        NSLog(@"推流url鉴权即将过期。更新url");
//        [self updateAuthURL];
//    }
    
    return self.pushURL;
}

- (void)onPacketsLost:(AlivcLivePusher *)pusher {
    
}


// MARK: - 退后台停止推流

- (void)addBackgroundNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}


- (void)applicationWillResignActive:(NSNotification *)notification {
    if (!self.livePusher) { return; }
    
    // 如果退后台不需要继续推流，则停止推流
    if ([self.livePusher isPushing]) {
        [self stopPush];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.toolsView.startPushButton.selected = NO;
        });
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (!self.livePusher) { return; }
    
//    [self.livePusher startPushWithURLAsync:self.pushURL];
}


// MARK: - UI

- (void)initSubviews {
    self.view.backgroundColor = UIColor.blackColor;
    
    [self.view addSubview:self.previewView];
    [self.view addSubview:self.toolsView];
    
}


- (UIView *)previewView {
    if (_previewView == nil) {
        _previewView = [[UIView alloc] init];
        _previewView.backgroundColor = UIColor.clearColor;
        _previewView.frame = [self getFullScreenFrame];
    }
    
    return _previewView;
}

- (PEPLivePusherToolsView *)toolsView {
    if (_toolsView == nil) {
        PEPLivePusherToolsView *toolsView = [PEPLivePusherToolsView.alloc initWithFrame:[self getFullScreenFrame] config:self.pushConfig];
        toolsView.backgroundColor = UIColor.clearColor;
        toolsView.delegate = self;

        _toolsView = toolsView;
    }

    return _toolsView;
}

- (void)showPusherInitErrorAlert:(int)error {
    [self showAlertViewWithErrorCode:error
                            errorStr:nil
                                 tag:kAlivcLivePusherVCAlertTag+31
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:PEPLivePusherLocalizedString(@"Init AlivcLivePusher Error")
                            delegate:self
                         cancelTitle:PEPLivePusherLocalizedString(@"exit")
                   otherButtonTitles:nil];
}

- (void)showPusherStartPreviewErrorAlert:(int)error isStart:(BOOL)isStart {
    
    NSString *message = PEPLivePusherLocalizedString(@"preview_stop_error");
    NSInteger tag = 0;
    if (isStart) {
        message = PEPLivePusherLocalizedString(@"preview_start_error");
        tag = kAlivcLivePusherVCAlertTag+32;
    }
    
    [self showAlertViewWithErrorCode:error
                            errorStr:nil
                                 tag:tag
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:message
                            delegate:self
                         cancelTitle:PEPLivePusherLocalizedString(@"ok")
                   otherButtonTitles:nil];
}


- (void)showPusherStartPushErrorAlert:(int)error isStart:(BOOL)isStart {
    
    NSString *message = PEPLivePusherLocalizedString(@"push_stop_error");
    if (isStart) {
        message = PEPLivePusherLocalizedString(@"push_start_error");
    }
    
    [self showAlertViewWithErrorCode:error
                            errorStr:nil
                                 tag:0
                               title:PEPLivePusherLocalizedString(@"dialog_title")
                             message:message
                            delegate:nil
                         cancelTitle:PEPLivePusherLocalizedString(@"ok")
                   otherButtonTitles:nil];
}


// MARK: - Timer

- (void)setupDebugTimer {
    __weak typeof(self) weakself = self;
    self.noticeTimer = [NSTimer scheduledTimerWithTimeInterval:kAlivcLivePusherNoticeTimerInterval target:weakself selector:@selector(noticeTimerAction:) userInfo:nil repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:self.noticeTimer forMode:NSDefaultRunLoopMode];
}

- (void)cancelTimer {
    
    if (self.noticeTimer) {
        [self.noticeTimer invalidate];
        self.noticeTimer = nil;
    }
}


- (void)noticeTimerAction:(NSTimer *)sender {
    if (!self.livePusher) { return; }
    
    BOOL isPushing = [self.livePusher isPushing];
    NSString *text = @"";
    if (isPushing) {
        text = [NSString stringWithFormat:@"%@:%@|%@:%@",PEPLivePusherLocalizedString(@"ispushing_log"), isPushing?@"YES":@"NO", PEPLivePusherLocalizedString(@"push_url_log"), [self.livePusher getPushURL]];
    } else {
        text = [NSString stringWithFormat:@"%@:%@",PEPLivePusherLocalizedString(@"ispushing_log"), isPushing?@"YES":@"NO"];
    }
    
    [self.toolsView updateInfoText:text];
}





// MARK: - Setter & Getter

- (AlivcLivePushConfig *)pushConfig {
    if (_pushConfig == nil) {
        AlivcLivePushConfig *pushConfig = [AlivcLivePushConfig.alloc initWithResolution:AlivcLivePushResolution540P];
        pushConfig.qualityMode = AlivcLivePushQualityModeFluencyFirst;
        pushConfig.audioChannel = AlivcLivePushAudioChannel_1;
        pushConfig.audioSampleRate = AlivcLivePushAudioSampleRate16000;
        pushConfig.cameraType = AlivcLivePushCameraTypeBack;
        if([[UIDevice currentDevice].model containsString:@"iPad"]) {
            if ([[UIDevice currentDevice] orientation] == UIInterfaceOrientationLandscapeRight) {
                pushConfig.orientation = AlivcLivePushOrientationLandscapeRight;
            }else{
                pushConfig.orientation = AlivcLivePushOrientationLandscapeLeft;
            }

        }
        _pushConfig = pushConfig;
    }
    
    return _pushConfig;
}

- (UIEdgeInsets)safeAreaInsets {
    if (@available(iOS 11.0, *)) {
        return UIApplication.sharedApplication.keyWindow.safeAreaInsets;
    } else {
        return UIEdgeInsetsZero;
    }
}


- (CGRect)getFullScreenFrame {
//    CGFloat top = self.safeAreaInsets.top <= 20 ? 0 : self.safeAreaInsets.top;
//    CGRect rect = CGRectMake(self.safeAreaInsets.left,
//                             top,
//                             CGRectGetWidth(self.view.bounds)-self.safeAreaInsets.left-self.safeAreaInsets.right,
//                             CGRectGetHeight(self.view.bounds)-top-self.safeAreaInsets.bottom);
    
    CGRect rect = self.view.bounds;
    return rect;
}


// MARK: - Private Method

- (void)showAlertViewWithErrorCode:(NSInteger)errorCode errorStr:(NSString *)errorStr tag:(NSInteger)tag title:(NSString *)title message:(NSString *)message delegate:(UIViewController *)delegate cancelTitle:(NSString *)cancel otherButtonTitles:(NSString *)otherTitles, ... {
    
    if (errorCode == ALIVC_LIVE_PUSHER_PARAM_ERROR) {
        errorStr = @"接口输入参数错误";
    }
    
    if (errorCode == ALIVC_LIVE_PUSHER_SEQUENCE_ERROR) {
        errorStr = @"接口调用顺序错误";
    }
    
#if DEBUG
    NSString *showMessage = [NSString stringWithFormat:@"%@\ncode:%ld message:%@", message, (long)errorCode, errorStr];
#else
    NSString *showMessage = message;
#endif
    
    [self alertWithTitle:title message:showMessage tag:tag presentingVC:delegate clickIndex:nil cancelButtonTitle:cancel otherButtonTitles:otherTitles, nil];
}

- (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
                   tag:(NSInteger)tag
          presentingVC:(UIViewController *)presentingVC
            clickIndex:(void(^)(NSInteger buttonIndex, UIAlertAction *action))callBack
     cancelButtonTitle:(NSString *)cancelButtonTitle
     otherButtonTitles:(NSString *)otherButtonTitles, ... {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.view.tag = tag;
    
    int a = 0;
    
    __weak typeof(self) weakself = self;

    if (cancelButtonTitle) {
        __block int b = a;
        UIAlertAction *action = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            if (callBack) {
                callBack(b, action);
            } else {
                if (tag == kAlivcLivePusherVCAlertTag+11 ||
                    tag == kAlivcLivePusherVCAlertTag+12 ||
                    tag == kAlivcLivePusherVCAlertTag+31 ||
                    tag == kAlivcLivePusherVCAlertTag+32 ||
                    tag == kAlivcLivePusherVCAlertTag+33) {
                    [weakself toolBarOnClickedBackButton:nil];
                }
                
                if (tag == kAlivcLivePusherVCAlertTag+22 ||
                    tag == kAlivcLivePusherVCAlertTag+23) {
                    [weakself reconnectPush];
                }
            }
            
        }];
        a++;
        [alert addAction:action];
    }
    
    if (otherButtonTitles) {
        __block int c = a;
        UIAlertAction *action = [UIAlertAction actionWithTitle:otherButtonTitles style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (callBack) {
                callBack(c, action);
            } else {
                if (tag == kAlivcLivePusherVCAlertTag+22 ||
                    tag == kAlivcLivePusherVCAlertTag+23) {
                    [weakself toolBarOnClickedBackButton:nil];
                }
            }

        }];
        [alert addAction:action];
        
        va_list args;
        va_start(args,otherButtonTitles);
        while ((otherButtonTitles = va_arg(args, NSString*))) {
            __block int d = ++a;
            UIAlertAction *action = [UIAlertAction actionWithTitle:otherButtonTitles style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                if (callBack) {
                    callBack(d, action);
                }
            }];
            [alert addAction:action];
        }
        va_end(args);
    }
    
    
    [self presentViewController:alert animated:true completion:nil];
}


// MARK: - Interface Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    switch (self.pushConfig.orientation) {
        case AlivcLivePushOrientationPortrait: {
            return UIInterfaceOrientationMaskPortrait;
            break;
        }
        case AlivcLivePushOrientationLandscapeLeft: {
            return UIInterfaceOrientationMaskLandscapeLeft;
            break;
        }
        case AlivcLivePushOrientationLandscapeRight: {
            return UIInterfaceOrientationMaskLandscapeRight;
            break;
        }
    }
}
-(BOOL)shouldAutorotate{

    return NO;

}

// MARK: - ModalPresentationStyle

- (UIModalPresentationStyle)modalPresentationStyle {
    return UIModalPresentationFullScreen;
}



@end
