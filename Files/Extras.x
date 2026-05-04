#import "Headers.h"
#import <Photos/Photos.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <objc/message.h>
#import <YouTubeHeader/YTDefaultSheetController.h>

@interface YTInlinePlayerScrubUserEducationView : UIView
@property (nonatomic, assign, readwrite) NSUInteger labelType;
- (void)setVisible:(BOOL)visible;
@end

@interface YTMainAppVideoPlayerOverlayView (YouModYTLiteExtras)
@property (nonatomic, assign, readonly) YTInlinePlayerScrubUserEducationView *scrubUserEducationView;
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouModYTLiteExtras)
- (void)play;
- (void)pause;
@end

@interface NSObject (YouModYTLiteDynamic)
- (BOOL)hasExtension:(id)extension;
- (id)getExtension:(id)extension;
@end

@interface YTDefaultSheetController (YouModYTLiteExtras)
+ (instancetype)sheetControllerWithParentResponder:(id)parentResponder;
- (void)addAction:(YTActionSheetAction *)action;
- (void)presentFromViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void(^)(void))completion;
@end

@interface YTQTMButton (YouModYTLiteExtras)
+ (instancetype)iconButton;
@end

static UIImage *YouModYTImageNamed(NSString *imageName, NSString *fallbackSystemName) {
    UIImage *image = [UIImage imageNamed:imageName inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
    if (!image && [UIImage respondsToSelector:@selector(systemImageNamed:)])
        image = [UIImage systemImageNamed:fallbackSystemName];
    return image;
}

static UIViewController *YouModTopViewController(void) {
    Class utils = NSClassFromString(@"YTUIUtils");
    [utils topViewControllerForPresenting];
    UIWindow *window = nil;
    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow) {
            window = candidate;
            break;
        }
    }
    if (!window) window = UIApplication.sharedApplication.windows.firstObject;
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController)
        controller = controller.presentedViewController;
    return controller;
}

static void YouModShowToast(NSString *message, id responder) {
    if (!message.length) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        Class toastClass = NSClassFromString(@"YTToastResponderEvent");
        [[toastClass eventWithMessage:message firstResponder:responder ?: YouModTopViewController()] send];
    });
}

static NSArray *YouModSpeedValues(void) {
    return @[@0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
}

static NSArray *YouModHoldSpeedValues(void) {
    return @[@0.0, @2.0, @0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
}

static CGFloat YouModSpeedForDefaultIndex(NSInteger index) {
    NSArray *values = YouModSpeedValues();
    if (index < 0 || index >= (NSInteger)values.count) index = 3;
    return [values[index] floatValue];
}

static CGFloat YouModSpeedForHoldIndex(NSInteger index) {
    NSArray *values = YouModHoldSpeedValues();
    if (index < 0 || index >= (NSInteger)values.count) index = 0;
    return [values[index] floatValue];
}

static BOOL YouModNetworkIsCellular(void) {
    struct sockaddr_in zeroAddress;
    memset(&zeroAddress, 0, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    if (!reachability) return NO;

    SCNetworkReachabilityFlags flags = 0;
    BOOL ok = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!ok) return NO;
    return (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0;
}

static NSString *YouModQualityLabelForIndex(NSInteger index, NSString *bestQualityLabel) {
    NSArray *qualityLabels = @[@"Default", bestQualityLabel ?: @"Best", @"2160p60", @"2160p", @"1440p60", @"1440p", @"1080p60", @"1080p", @"720p60", @"720p", @"480p", @"360p"];
    if (index < 0 || index >= (NSInteger)qualityLabels.count) index = 0;
    return qualityLabels[index];
}

static NSInteger YouModQualityNumber(NSString *qualityLabel) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d+)p" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:qualityLabel ?: @"" options:0 range:NSMakeRange(0, qualityLabel.length)];
    if (!match || match.numberOfRanges < 2) return 0;
    return [[qualityLabel substringWithRange:[match rangeAtIndex:1]] integerValue];
}

static void YouModApplyDefaultPlaybackSpeed(YTPlayerViewController *player) {
    NSInteger speedIndex = INTFORVAL(DefaultPlaybackRateIndex);
    if (speedIndex == 3) return;
    CGFloat rate = YouModSpeedForDefaultIndex(speedIndex);
    [player setPlaybackRate:rate];
}

static void YouModApplyAutoQuality(YTPlayerViewController *player) {
    NSInteger qualityIndex = YouModNetworkIsCellular() ? INTFORVAL(AutoQualityCellularIndex) : INTFORVAL(AutoQualityWiFiIndex);
    if (qualityIndex == 0) return;

    id activeVideo = [player activeVideo];
    NSArray *formats = [activeVideo selectableVideoFormats];
    if (!formats.count) return;

    NSString *bestQualityLabel = nil;
    NSInteger highestScore = 0;
    for (MLFormat *format in formats) {
        NSInteger resolution = [format singleDimensionResolution];
        CGFloat fps = [format FPS];
        NSInteger score = resolution * 100 + fps;
        if (score > highestScore) {
            highestScore = score;
            bestQualityLabel = [format qualityLabel];
        }
    }

    NSString *qualityLabel = YouModQualityLabelForIndex(qualityIndex, bestQualityLabel);
    if (!qualityLabel.length || [qualityLabel isEqualToString:@"Default"]) return;
    if ([qualityLabel isEqualToString:bestQualityLabel]) {
        BOOL exactMatch = NO;
        for (MLFormat *format in formats) {
            if ([[format qualityLabel] isEqualToString:qualityLabel]) {
                exactMatch = YES;
                break;
            }
        }
        if (!exactMatch) {
            NSInteger target = YouModQualityNumber(qualityLabel);
            NSInteger bestDifference = NSIntegerMax;
            NSString *closest = qualityLabel;
            for (MLFormat *format in formats) {
                NSString *candidate = [format qualityLabel];
                NSInteger candidateQuality = YouModQualityNumber(candidate);
                if (!candidateQuality) continue;
                NSInteger difference = labs(candidateQuality - target);
                if (difference < bestDifference) {
                    bestDifference = difference;
                    closest = candidate;
                }
            }
            qualityLabel = closest;
        }
    }

    Class constraintClass = NSClassFromString(@"MLQuickMenuVideoQualitySettingFormatConstraint");
    id constraint = [[constraintClass alloc] initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:qualityLabel];
    SEL setter = @selector(setVideoFormatConstraint:);
    void (*send)(id, SEL, id) = (void *)objc_msgSend;
    send(activeVideo, setter, constraint);
}

static void YouModOpenShortAsRegularVideo(YTPlayerViewController *player) {
    if (!IS_ENABLED(ShortsToRegular)) return;
    NSString *videoID = [player respondsToSelector:@selector(contentVideoID)] ? [player contentVideoID] : [player currentVideoID];
    if (!videoID.length || ![player.parentViewController isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) return;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"vnd.youtube://%@", videoID]];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

static __weak YTPlayerViewController *YouModSleepTimerPlayer = nil;
static NSTimer *YouModSleepTimerTimer = nil;
static BOOL YouModSleepTimerAtEndOfVideo = NO;

static void YouModCancelSleepTimer(void) {
    [YouModSleepTimerTimer invalidate];
    YouModSleepTimerTimer = nil;
    YouModSleepTimerAtEndOfVideo = NO;
}

static void YouModPauseForSleepTimer(void) {
    YTPlayerViewController *player = YouModSleepTimerPlayer;
    [player pause];
    YouModCancelSleepTimer();
    YouModShowToast(@"Sleep timer ended", player);
}

static void YouModStartSleepTimer(NSTimeInterval seconds, YTPlayerViewController *player) {
    YouModCancelSleepTimer();
    YouModSleepTimerPlayer = player;
    YouModSleepTimerTimer = [NSTimer scheduledTimerWithTimeInterval:seconds repeats:NO block:^(__unused NSTimer *timer) {
        YouModPauseForSleepTimer();
    }];
    YouModShowToast([NSString stringWithFormat:@"Sleep timer: %.0f minutes", seconds / 60.0], player);
}

static void YouModPresentSleepTimerCustomMinutes(YTPlayerViewController *player) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sleep timer" message:@"Enter minutes" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"Minutes";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Start" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSInteger minutes = alert.textFields.firstObject.text.integerValue;
        if (minutes <= 0) {
            YouModShowToast(@"Enter a valid number of minutes", player);
            return;
        }
        YouModStartSleepTimer((NSTimeInterval)minutes * 60.0, player);
    }]];
    [YouModTopViewController() presentViewController:alert animated:YES completion:nil];
}

static NSDate *YouModSleepTimerDateFromClockText(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) return nil;

    NSArray *formats = @[@"H:mm", @"HH:mm", @"h:mm a", @"h:mma"];
    NSDate *parsed = nil;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    for (NSString *format in formats) {
        formatter.dateFormat = format;
        parsed = [formatter dateFromString:trimmed];
        if (parsed) break;
    }
    if (!parsed) return nil;

    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateComponents *clock = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:parsed];
    NSDateComponents *today = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:NSDate.date];
    today.hour = clock.hour;
    today.minute = clock.minute;
    today.second = 0;
    NSDate *target = [calendar dateFromComponents:today];
    if (target.timeIntervalSinceNow <= 5.0)
        target = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:target options:0];
    return target;
}

static void YouModPresentSleepTimerEndAtTime(YTPlayerViewController *player) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sleep timer" message:@"Enter a time" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.placeholder = @"23:30 or 11:30 PM";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Start" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSDate *target = YouModSleepTimerDateFromClockText(alert.textFields.firstObject.text);
        if (!target) {
            YouModShowToast(@"Enter a valid time", player);
            return;
        }
        YouModStartSleepTimer(target.timeIntervalSinceNow, player);
    }]];
    [YouModTopViewController() presentViewController:alert animated:YES completion:nil];
}

void YouModApplyYTLitePlaybackDefaults(YTPlayerViewController *player) {
    if (!player) return;
    YouModSleepTimerPlayer = player;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        YouModApplyDefaultPlaybackSpeed(player);
        YouModOpenShortAsRegularVideo(player);
    });
    if (INTFORVAL(AutoQualityWiFiIndex) != 0 || INTFORVAL(AutoQualityCellularIndex) != 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            YouModApplyAutoQuality(player);
        });
    }
}

static NSString *YouModEndTimeStringForVideo(YTSingleVideoController *video, YTSingleVideoTime *time) {
    CGFloat totalTime = 0;
    totalTime = video.totalMediaTime;
    if (totalTime <= 0 || time.time < 0) return nil;
    CGFloat rate = 1.0;
    // FIXME: find a vaild selector for this
    @try {
        NSNumber *rateValue = [video valueForKey:@"playbackRate"];
        if (rateValue.floatValue > 0) rate = rateValue.floatValue;
    } @catch (NSException *exception) {}
    NSTimeInterval remainingTime = MAX(0, (lround(totalTime) - lround(time.time)) / rate);

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = IS_ENABLED(Use24HourTime) ? @"HH:mm" : @"h:mm a";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:remainingTime]];
}

void YouModHandleYTLiteTimeUpdate(YTPlayerViewController *player, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (YouModSleepTimerAtEndOfVideo) {
        CGFloat totalTime = 0;
        totalTime = video.totalMediaTime;
        if (totalTime > 0 && totalTime - time.time <= 1.0)
            YouModPauseForSleepTimer();
    }

    if (IS_ENABLED(VideoEndTime)) {
        NSString *endTime = YouModEndTimeStringForVideo(video, time);
        YTPlayerView *playerView = [player playerView]; 
        // (YTPlayerView *)player.view;
        UIView *overlayView = playerView.overlayView;
        if ([overlayView isKindOfClass:NSClassFromString(@"YTMainAppVideoPlayerOverlayView")]) {
            YTInlinePlayerBarContainerView *playerBar = [(YTMainAppVideoPlayerOverlayView *)overlayView playerBar];
            YTLabel *durationLabel = playerBar.durationLabel;
            if (endTime.length && durationLabel.text.length && ![durationLabel.text containsString:endTime]) {
                objc_setAssociatedObject(playerBar, @selector(YouModEndTimeStringForVideo), endTime, OBJC_ASSOCIATION_COPY_NONATOMIC);
                durationLabel.text = [durationLabel.text stringByAppendingFormat:@" • %@", endTime];
                [durationLabel sizeToFit];
            }
        }
    }

    // ???
    if (IS_ENABLED(AutoSkipShorts)) {
        CGFloat totalTime = 0;
        totalTime = video.totalMediaTime;
        if (totalTime > 0 && floor(time.time) >= floor(totalTime) && [player.parentViewController isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) {
            SEL advance = @selector(reelContentViewRequestsAdvanceToNextVideo:);
            if ([player.parentViewController respondsToSelector:advance]) {
                void (*send)(id, SEL, id) = (void *)objc_msgSend;
                send(player.parentViewController, advance, nil);
            }
        }
    }
}

// Untested
%hook YTColdConfig
- (BOOL)videoZoomFreeZoomEnabledGlobalConfig { return IS_ENABLED(NoFreeZoom) ? NO : %orig; }
- (BOOL)enableHideChipsInTheCommentsHeaderOnScrollIos { return IS_ENABLED(StickSortComments) ? NO : %orig; }
- (BOOL)enableChipsInTheCommentsHeaderIos { return IS_ENABLED(HideSortComments) ? NO : %orig; }
- (BOOL)queueClientGlobalConfigEnableFloatingPlaylistMinibar { return IS_ENABLED(PlaylistOldMinibar) ? NO : %orig; }
- (BOOL)iosUseSystemVolumeControlInFullscreen { return IS_ENABLED(StockVolumeHUD) ? YES : %orig; }
%end

%hook YTInlinePlayerBarContainerView
- (void)setPeekableViewVisible:(BOOL)visible {
    %orig;
    if (!IS_ENABLED(VideoEndTime)) return;
    NSString *endTime = objc_getAssociatedObject(self, @selector(YouModEndTimeStringForVideo));
    if (endTime.length && self.durationLabel.text.length && ![self.durationLabel.text containsString:endTime]) {
        self.durationLabel.text = [self.durationLabel.text stringByAppendingFormat:@" • %@", endTime];
        [self.durationLabel sizeToFit];
    }
}
- (id)quietProgressBarColor { return IS_ENABLED(RedProgressBar) ? [UIColor redColor] : %orig; }
%end

// Untested
/*
%hook YTModularPlayerBarController
- (void)setEnableSnapToChapter:(BOOL)arg1 { IS_ENABLED(DontSnapToChapter) ? %orig(NO) : %orig; }
%end
*/

%hook YTMainAppVideoPlayerOverlayViewController
- (void)didPressPause:(id)sender {
    %orig;
    if (!IS_ENABLED(CopyWithTimestamp)) return;
    CGFloat mediaTimeIn = self.mediaTime;
    NSString *vidID = self.videoID;
    if (vidID.length)
        UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@&t=%lds", vidID, (long)mediaTimeIn];
}
%end

static CGFloat YouModRateBeforeHoldToSpeed = 1.0;

static void YouModAddSleepTimerAction(YTDefaultSheetController *sheet, NSString *title, NSString *iconName, NSString *fallbackIconName, void (^handler)(void)) {
    UIImage *icon = YouModYTImageNamed(iconName, fallbackIconName);
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:title iconImage:icon style:0 handler:^(__unused YTActionSheetAction *action) {
        if (handler) handler();
    }]];
}

static void YouModManageHoldToSpeed(UILongPressGestureRecognizer *gesture, YTMainAppVideoPlayerOverlayViewController *delegate, YTInlinePlayerScrubUserEducationView *educationView) {
    NSInteger speedIndex = INTFORVAL(HoldToSpeedIndex);
    if (speedIndex == 0 || !delegate) return;

    CGFloat speed = YouModSpeedForHoldIndex(speedIndex);
    UILabel *label = [educationView valueForKey:@"_userEducationLabel"];
    educationView.labelType = 1;
    label.text = [NSString stringWithFormat:@"Playback speed: %.2gx", speed];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        YouModRateBeforeHoldToSpeed = [delegate currentPlaybackRate];
        [delegate setPlaybackRate:speed];
        [educationView setVisible:YES];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        [delegate setPlaybackRate:YouModRateBeforeHoldToSpeed];
        [educationView setVisible:NO];
    }
}

%hook YTMainAppVideoPlayerOverlayView
- (void)setSeekAnywherePanGestureRecognizer:(id)arg1 {
    %orig;
    if (INTFORVAL(HoldToSpeedIndex) != 0 && !objc_getAssociatedObject(self, @selector(YouModHoldToSpeed:))) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModHoldToSpeed:)];
        longPress.minimumPressDuration = 0.3;
        [self addGestureRecognizer:longPress];
        objc_setAssociatedObject(self, @selector(YouModHoldToSpeed:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (IS_ENABLED(SleepTimerEnabled) && !objc_getAssociatedObject(self, @selector(YouModShowSleepTimer:))) {
        UILongPressGestureRecognizer *sleepPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModShowSleepTimer:)];
        sleepPress.numberOfTouchesRequired = 2;
        sleepPress.minimumPressDuration = 0.5;
        [self addGestureRecognizer:sleepPress];
        objc_setAssociatedObject(self, @selector(YouModShowSleepTimer:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)YouModHoldToSpeed:(UILongPressGestureRecognizer *)gesture {
    YouModManageHoldToSpeed(gesture, self.delegate, self.scrubUserEducationView);
}

%new
- (void)YouModShowSleepTimer:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    YTPlayerViewController *player = (YTPlayerViewController *)(self.delegate.parentViewController ?: YouModSleepTimerPlayer);
    YouModSleepTimerPlayer = player;
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
    NSArray *timerRows = @[
        @{@"title": @"15 minutes", @"seconds": @900},
        @{@"title": @"30 minutes", @"seconds": @1800},
        @{@"title": @"60 minutes", @"seconds": @3600},
    ];
    for (NSDictionary *row in timerRows) {
        YouModAddSleepTimerAction(sheet, row[@"title"], @"yt_outline_time_24pt", @"timer", ^{
            YouModStartSleepTimer([row[@"seconds"] doubleValue], player);
        });
    }
    YouModAddSleepTimerAction(sheet, @"Custom minutes...", @"yt_outline_time_24pt", @"timer", ^{
        YouModPresentSleepTimerCustomMinutes(player);
    });
    YouModAddSleepTimerAction(sheet, @"End at time...", @"yt_outline_time_24pt", @"timer", ^{
        YouModPresentSleepTimerEndAtTime(player);
    });
    YouModAddSleepTimerAction(sheet, @"End of video", @"yt_outline_time_24pt", @"timer", ^{
        YouModCancelSleepTimer();
        YouModSleepTimerPlayer = player;
        YouModSleepTimerAtEndOfVideo = YES;
        YouModShowToast(@"Sleep timer: end of video", player);
    });
    YouModAddSleepTimerAction(sheet, @"Turn off", @"yt_outline_close_24pt", @"xmark", ^{
        YouModCancelSleepTimer();
        YouModShowToast(@"Sleep timer off", player);
    });
    [sheet presentFromViewController:YouModTopViewController() animated:YES completion:nil];
}
%end


%hook YTSpeedmasterController
- (void)speedmasterDidLongPressWithRecognizer:(UILongPressGestureRecognizer *)gesture {
    NSInteger speedIndex = INTFORVAL(HoldToSpeedIndex);
    if (speedIndex == 0) return;
    if (speedIndex == 1) return %orig;
    YTMainAppVideoPlayerOverlayViewController *delegate = [(id)self valueForKey:@"_delegate"];
    YTInlinePlayerScrubUserEducationView *educationView = nil;
    // FIXME: Find a new selector for this
    @try {
        educationView = [[delegate videoPlayerOverlayView] valueForKey:@"scrubUserEducationView"];
    } @catch (NSException *exception) {}
    YouModManageHoldToSpeed(gesture, delegate, educationView);
}
%end

%hook YTShortsStartupCoordinator
- (id)evaluateResumeToShorts { return IS_ENABLED(ResumeShorts) ? nil : %orig; }
%end

%hook YTShortsStartupCoordinatorImpl
- (id)evaluateResumeToShorts { return IS_ENABLED(ResumeShorts) ? nil : %orig; }
%end

%hook YTReelPausedStateCarouselView
- (void)setPausedStateCarouselVisible:(BOOL)arg1 animated:(BOOL)arg2 { IS_ENABLED(HideShortsSubscriptButton) ? %orig(NO, arg2) : %orig; }
%end

%hook YTReelHeaderView
- (void)setTitleLabelVisible:(BOOL)arg1 animated:(BOOL)arg2 { IS_ENABLED(HideShortsLogo) ? %orig(NO, arg2) : %orig; }
%end

// wth is this
%hook YTReelTransparentStackView
- (void)layoutSubviews {
    %orig;
    for (UIView *button in ((UIView *)self).subviews) {
        id renderer = nil;
        @try {
            renderer = [button valueForKey:@"_buttonRenderer"];
        } @catch (NSException *exception) {}
        id icon = [renderer valueForKey:@"icon"];
        NSInteger iconType = [[icon valueForKey:@"iconType"] integerValue];
        if ((IS_ENABLED(HideShortsSearchButton) && iconType == 1045) ||
            (IS_ENABLED(HideShortsCameraButton) && iconType == 1046) ||
            (IS_ENABLED(HideShortsMoreButton) && iconType == 1047)) {
            button.hidden = YES;
        }
    }
}
%end

// may not work
%hook YTReelWatchHeaderView
- (void)setChannelBarElementRenderer:(id)renderer { if (!IS_ENABLED(HideShortsChannelName)) %orig; }
- (void)setHeaderRenderer:(id)renderer { if (!IS_ENABLED(HideShortsDescription)) %orig; }
- (void)setShortsVideoTitleElementRenderer:(id)renderer { if (!IS_ENABLED(HideShortsDescription)) %orig; }
- (void)setSoundMetadataElementRenderer:(id)renderer { if (!IS_ENABLED(HideShortsAudioTrack)) %orig; }
- (void)setActionElement:(id)renderer { if (!IS_ENABLED(HideShortsPromoCards)) %orig; }
- (void)setBadgeRenderer:(id)renderer { if (!IS_ENABLED(HideShortsThanks)) %orig; }
- (void)setMultiFormatLinkElementRenderer:(id)renderer { if (!IS_ENABLED(HideShortsSource)) %orig; }
%end

static BOOL YouModShortsOverlayShown = YES;

%hook YTPlayerView
- (void)didPinch:(UIPinchGestureRecognizer *)gesture {
    %orig;
    id playerViewDelegate = [self valueForKey:@"_playerViewDelegate"];
    id parent = nil;
    @try {
        parent = [playerViewDelegate valueForKey:@"_parentViewController"];
    } @catch (NSException *exception) {}
    if (!IS_ENABLED(PinchToFullscreenShorts) || ![parent isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) return;

    UIView *contentView = [(UIViewController *)parent view];
    UIView *playbackOverlay = nil;
    @try {
        playbackOverlay = [contentView valueForKey:@"_playbackOverlay"];
    } @catch (NSException *exception) {}
    UIWindow *window = nil;
    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow) {
            window = candidate;
            break;
        }
    }
    if (!window) window = UIApplication.sharedApplication.windows.firstObject;
    id appVC = window.rootViewController;

    if (gesture.scale > 1) {
        if (!IS_ENABLED(ShortsOnlyMode) && [appVC respondsToSelector:@selector(hidePivotBar)])
            [appVC performSelector:@selector(hidePivotBar)];
        [UIView animateWithDuration:0.3 animations:^{
            playbackOverlay.alpha = 0;
            YouModShortsOverlayShown = NO;
        }];
    } else {
        if (!IS_ENABLED(ShortsOnlyMode) && [appVC respondsToSelector:@selector(showPivotBar)])
            [appVC performSelector:@selector(showPivotBar)];
        [UIView animateWithDuration:0.3 animations:^{
            playbackOverlay.alpha = 1;
            YouModShortsOverlayShown = YES;
        }];
    }
}
%end

%hook YTReelContentView
- (void)setPlaybackView:(id)arg1 {
    %orig;
    UIView *playbackOverlay = [self valueForKey:@"_playbackOverlay"];
    playbackOverlay.alpha = YouModShortsOverlayShown ? 1 : 0;
    if (IS_ENABLED(ShortsOnlyMode) && !objc_getAssociatedObject(self, @selector(YouModTurnShortsOnlyModeOff:))) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModTurnShortsOnlyModeOff:)];
        longPress.numberOfTouchesRequired = 2;
        longPress.minimumPressDuration = 0.5;
        [(UIView *)self addGestureRecognizer:longPress];
        objc_setAssociatedObject(self, @selector(YouModTurnShortsOnlyModeOff:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)YouModTurnShortsOnlyModeOff:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:ShortsOnlyMode];
    [[NSUserDefaults standardUserDefaults] synchronize];
    YouModShowToast(@"Shorts only mode off", self);
    UIWindow *window = nil;
    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow) {
            window = candidate;
            break;
        }
    }
    if (!window) window = UIApplication.sharedApplication.windows.firstObject;
    id appVC = window.rootViewController;
    if ([appVC respondsToSelector:@selector(showPivotBar)])
        [appVC performSelector:@selector(showPivotBar) withObject:nil afterDelay:1.0];
}
%end

%hook YTAppViewController
- (void)showPivotBar {
    if (!IS_ENABLED(ShortsOnlyMode)) {
        %orig;
        YouModShortsOverlayShown = YES;
    }
}
%end

%hook YTAppViewControllerImpl
- (void)showPivotBar {
    if (!IS_ENABLED(ShortsOnlyMode)) {
        %orig;
        YouModShortsOverlayShown = YES;
    }
}
%end

%hook YTReelWatchRootViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (IS_ENABLED(ShortsOnlyMode)) {
        id parent = ((UIViewController *)self).navigationController.parentViewController;
        if ([parent respondsToSelector:@selector(hidePivotBar)])
            [parent performSelector:@selector(hidePivotBar)];
    }
}
%end

static NSArray *YouModNodeAncestors(id node) {
    @try {
        id supernodes = [node valueForKey:@"_supernodes"];
        if ([supernodes respondsToSelector:@selector(allObjects)])
            return [supernodes allObjects];
    } @catch (NSException *exception) {}
    return @[];
}

static UIViewController *YouModClosestViewControllerForNode(id node) {
    if ([node respondsToSelector:@selector(closestViewController)])
        return [node closestViewController];
    @try {
        return [node valueForKey:@"_closestViewController"];
    } @catch (NSException *exception) {}
    return YouModTopViewController();
}

static void YouModDownloadImageFromURL(id responder, NSURL *URL, BOOL saveToPhotos) {
    NSString *URLString = URL.absoluteString;
    if (IS_ENABLED(FixAlbums) && [URLString hasPrefix:@"https://yt3."])
        URLString = [URLString stringByReplacingOccurrencesOfString:@"https://yt3." withString:@"https://yt4."];
    if ([URLString containsString:@"c-fcrop"]) {
        NSRange croppedRange = [URLString rangeOfString:@"c-fcrop"];
        if (croppedRange.location != NSNotFound)
            URLString = [URLString stringByReplacingOccurrencesOfString:[URLString substringFromIndex:croppedRange.location] withString:@"nd-v1"];
    }

    NSURL *downloadURL = [NSURL URLWithString:URLString] ?: URL;
    [[NSURLSession.sharedSession dataTaskWithURL:downloadURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data.length) {
            YouModShowToast(error.localizedDescription ?: @"Image download failed", responder);
            return;
        }
        if (saveToPhotos) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                [request addResourceWithType:PHAssetResourceTypePhoto data:data options:nil];
            } completionHandler:^(BOOL success, NSError *error) {
                YouModShowToast(success ? @"Saved" : (error.localizedDescription ?: @"Save failed"), responder);
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIPasteboard.generalPasteboard.image = [UIImage imageWithData:data];
                YouModShowToast(@"Copied", responder);
            });
        }
    }] resume];
}

static void YouModImageFromLayer(CALayer *layer, UIColor *backgroundColor, void (^completion)(UIImage *image)) {
    if (!layer || !completion) return;
    UIGraphicsBeginImageContextWithOptions(layer.frame.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, (backgroundColor ?: UIColor.systemBackgroundColor).CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, layer.frame.size.width, layer.frame.size.height));
    [layer renderInContext:context];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    completion(image);
}

static void YouModPresentNodeSheet(NSString *title, id node, NSArray <YTActionSheetAction *> *actions) {
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
    for (YTActionSheetAction *action in actions)
        [sheet addAction:action];
    [sheet presentFromViewController:YouModClosestViewControllerForNode(node) animated:YES completion:nil];
}

%hook ASDisplayNode
- (void)setFrame:(CGRect)frame {
    %orig;
    NSString *identifier = [self valueForKey:@"_accessibilityIdentifier"];

    if (IS_ENABLED(CommentManager) && [identifier isEqualToString:@"id.comment.content.label"] && [self isKindOfClass:NSClassFromString(@"ASTextNode")]) {
        NSString *comment = nil;
        // The ivar is not available
        @try {
            comment = [[self valueForKey:@"attributedText"] string];
        } @catch (NSException *exception) {}
        if (comment.length) {
            for (id ancestor in YouModNodeAncestors(self)) {
                if ([[ancestor description] containsString:@"id.ui.comment_cell"]) {
                    objc_setAssociatedObject(ancestor, @selector(YouModCommentManagerText), comment, OBJC_ASSOCIATION_COPY_NONATOMIC);
                    break;
                }
            }
        }
    }

    if (IS_ENABLED(PostManager) && [self isKindOfClass:NSClassFromString(@"ELMExpandableTextNode")]) {
        NSString *text = nil;
        // The ivar is not available
        @try {
            id textNode = [self valueForKeyPath:@"currentTextNode"];
            text = [[textNode valueForKey:@"attributedText"] string];
        } @catch (NSException *exception) {}
        if (text.length) {
            for (id ancestor in YouModNodeAncestors(self)) {
                if ([[ancestor description] containsString:@"id.ui.backstage.original_post"]) {
                    objc_setAssociatedObject(ancestor, @selector(YouModPostManagerText), text, OBJC_ASSOCIATION_COPY_NONATOMIC);
                    break;
                }
            }
        }
    }
}
%end

%hook YTImageZoomNode
- (BOOL)gestureRecognizer:(id)arg1 shouldRecognizeSimultaneouslyWithGestureRecognizer:(id)arg2 {
    BOOL loaded = [[self valueForKey:@"_didLoadImage"] boolValue];
    if (IS_ENABLED(PostManager) && loaded) {
        NSURL *URL = nil;
        // Not available - 100% AI generated
        @try {
            URL = [(id)self valueForKey:@"URL"];
        } @catch (NSException *exception) {}
        if (URL) {
            for (id ancestor in YouModNodeAncestors(self)) {
                if ([[ancestor description] containsString:@"id.ui.backstage.original_post"]) {
                    objc_setAssociatedObject(ancestor, @selector(YouModPostManagerURL), URL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    break;
                }
            }
        }
    }
    return %orig;
}
%end

%hook _ASDisplayView
- (void)setKeepalive_node:(id)arg1 {
    %orig;
    if (objc_getAssociatedObject(self, @selector(YouModExtrasLongPress:))) return;
    NSString *description = self.description;
    SEL selector = nil;
    if (IS_ENABLED(PostManager) && [description containsString:@"id.ui.backstage.original_post"])
        selector = @selector(YouModPostManager:);
    else if (IS_ENABLED(SaveProfilePhoto) && [description containsString:@"ELMImageNode-View"])
        selector = @selector(YouModSaveProfilePhoto:);
    else if (IS_ENABLED(CommentManager) && [description containsString:@"id.ui.comment_cell"])
        selector = @selector(YouModCommentManager:);
    if (!selector) return;

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:selector];
    longPress.minimumPressDuration = 0.3;
    [self addGestureRecognizer:longPress];
    objc_setAssociatedObject(self, @selector(YouModExtrasLongPress:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)YouModSaveProfilePhoto:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    NSURL *URL = nil;
    // Not available
    @try {
        URL = [self.keepalive_node valueForKey:@"URL"];
    } @catch (NSException *exception) {}
    if (!URL) return;
    NSString *URLString = URL.absoluteString;
    NSRange sizeRange = [URLString rangeOfString:@"=s"];
    if (sizeRange.location != NSNotFound) {
        NSRange dashRange = [URLString rangeOfString:@"-" options:0 range:NSMakeRange(sizeRange.location, URLString.length - sizeRange.location)];
        if (dashRange.location != NSNotFound)
            URLString = [URLString stringByReplacingCharactersInRange:NSMakeRange(sizeRange.location + 2, dashRange.location - sizeRange.location - 2) withString:@"1024"];
    }
    NSURL *profileURL = [NSURL URLWithString:URLString] ?: URL;
    UIImage *imageIcon = YouModYTImageNamed(@"yt_outline_image_24pt", @"photo");
    UIImage *copyIcon = YouModYTImageNamed(@"yt_outline_library_image_24pt", @"doc.on.doc");
    YTActionSheetAction *save = [%c(YTActionSheetAction) actionWithTitle:@"Save profile photo" iconImage:imageIcon style:0 handler:^(YTActionSheetAction *action) {
        YouModDownloadImageFromURL(self.keepalive_node, profileURL, YES);
    }];
    YTActionSheetAction *copy = [%c(YTActionSheetAction) actionWithTitle:@"Copy profile photo" iconImage:copyIcon style:0 handler:^(YTActionSheetAction *action) {
        YouModDownloadImageFromURL(self.keepalive_node, profileURL, NO);
    }];
    YouModPresentNodeSheet(@"Profile photo", self.keepalive_node, @[save, copy]);
}

%new
- (void)YouModPostManager:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    id containerNode = self.keepalive_node;
    NSString *text = objc_getAssociatedObject(containerNode, @selector(YouModPostManagerText));
    NSURL *URL = objc_getAssociatedObject(containerNode, @selector(YouModPostManagerURL));
    id nodeForLayer = [[containerNode valueForKey:@"_yogaChildren"] firstObject];
    // Huh?
    CALayer *layer = [nodeForLayer valueForKey:@"layer"] ?: self.layer;
    UIColor *backgroundColor = YouModClosestViewControllerForNode(containerNode).view.backgroundColor;
    NSMutableArray *actions = [NSMutableArray array];
    UIImage *textIcon = YouModYTImageNamed(@"yt_outline_message_bubble_right_24pt", @"text.bubble");
    UIImage *imageIcon = YouModYTImageNamed(@"yt_outline_image_24pt", @"photo");
    UIImage *copyIcon = YouModYTImageNamed(@"yt_outline_library_image_24pt", @"doc.on.doc");

    [actions addObject:[%c(YTActionSheetAction) actionWithTitle:@"Copy post text" iconImage:textIcon style:0 handler:^(YTActionSheetAction *action) {
        if (text.length) {
            UIPasteboard.generalPasteboard.string = text;
            YouModShowToast(@"Copied", containerNode);
        }
    }]];
    if (URL) {
        [actions addObject:[%c(YTActionSheetAction) actionWithTitle:@"Save current image" iconImage:imageIcon style:0 handler:^(YTActionSheetAction *action) {
            YouModDownloadImageFromURL(containerNode, URL, YES);
        }]];
        [actions addObject:[%c(YTActionSheetAction) actionWithTitle:@"Copy current image" iconImage:copyIcon style:0 handler:^(YTActionSheetAction *action) {
            YouModDownloadImageFromURL(containerNode, URL, NO);
        }]];
    }
    [actions addObject:[%c(YTActionSheetAction) actionWithTitle:@"Save post as image" iconImage:imageIcon style:0 handler:^(YTActionSheetAction *action) {
        YouModImageFromLayer(layer, backgroundColor, ^(UIImage *image) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            YouModShowToast(@"Saved", containerNode);
        });
    }]];
    [actions addObject:[%c(YTActionSheetAction) actionWithTitle:@"Copy post as image" iconImage:copyIcon style:0 handler:^(YTActionSheetAction *action) {
        YouModImageFromLayer(layer, backgroundColor, ^(UIImage *image) {
            UIPasteboard.generalPasteboard.image = image;
            YouModShowToast(@"Copied", containerNode);
        });
    }]];
    YouModPresentNodeSheet(@"Post", containerNode, actions);
}

%new
- (void)YouModCommentManager:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    id containerNode = self.keepalive_node;
    NSString *comment = objc_getAssociatedObject(containerNode, @selector(YouModCommentManagerText));
    CALayer *layer = self.layer;
    UIColor *backgroundColor = YouModClosestViewControllerForNode(containerNode).view.backgroundColor;
    UIImage *textIcon = YouModYTImageNamed(@"yt_outline_message_bubble_right_24pt", @"text.bubble");
    UIImage *imageIcon = YouModYTImageNamed(@"yt_outline_image_24pt", @"photo");
    UIImage *copyIcon = YouModYTImageNamed(@"yt_outline_library_image_24pt", @"doc.on.doc");

    YTActionSheetAction *copyText = [%c(YTActionSheetAction) actionWithTitle:@"Copy comment text" iconImage:textIcon style:0 handler:^(YTActionSheetAction *action) {
        if (comment.length) {
            UIPasteboard.generalPasteboard.string = comment;
            YouModShowToast(@"Copied", containerNode);
        }
    }];
    YTActionSheetAction *saveImage = [%c(YTActionSheetAction) actionWithTitle:@"Save comment as image" iconImage:imageIcon style:0 handler:^(YTActionSheetAction *action) {
        YouModImageFromLayer(layer, backgroundColor, ^(UIImage *image) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            YouModShowToast(@"Saved", containerNode);
        });
    }];
    YTActionSheetAction *copyImage = [%c(YTActionSheetAction) actionWithTitle:@"Copy comment as image" iconImage:copyIcon style:0 handler:^(YTActionSheetAction *action) {
        YouModImageFromLayer(layer, backgroundColor, ^(UIImage *image) {
            UIPasteboard.generalPasteboard.image = image;
            YouModShowToast(@"Copied", containerNode);
        });
    }];
    YouModPresentNodeSheet(@"Comment", containerNode, @[copyText, saveImage, copyImage]);
}
%end

%hook YTDefaultSheetController
- (void)addAction:(YTActionSheetAction *)action {
    NSString *identifier = [action valueForKey:@"_accessibilityIdentifier"];
    NSDictionary *actionsToRemove = @{
        @"7": @(IS_ENABLED(RemoveDownloadMenu)),
        @"1": @(IS_ENABLED(RemoveWatchLaterMenu)),
        @"3": @(IS_ENABLED(RemoveSaveToPlaylistMenu)),
        @"5": @(IS_ENABLED(RemoveShareMenu)),
        @"12": @(IS_ENABLED(RemoveNotInterestedMenu)),
        @"31": @(IS_ENABLED(RemoveDontRecommendMenu)),
        @"58": @(IS_ENABLED(RemoveReportMenu))
    };
    if (![actionsToRemove[identifier] boolValue]) %orig;
}
%end

%hook YTWatchNextResultsViewController
- (void)setVisibleSections:(NSInteger)arg1 { IS_ENABLED(HideRelatedWatchNexts) ? %orig(1) : %orig; }
%end

%hook YTAsyncCollectionView
- (id)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = %orig;
    if ([cell isKindOfClass:objc_lookUpClass("_ASCollectionViewCell")]) {
        id node = [cell respondsToSelector:@selector(node)] ? [(id)cell node] : nil;
        NSString *identifier = [node respondsToSelector:@selector(accessibilityIdentifier)] ? [node accessibilityIdentifier] : nil;
        if ([identifier isEqualToString:@"statement_banner.view"] ||
            (([identifier isEqualToString:@"eml.shorts-grid"] || [identifier isEqualToString:@"eml.shorts-shelf"]) && IS_ENABLED(HideShortsShelf))) {
            [(UICollectionView *)self deleteItemsAtIndexPaths:@[indexPath]];
        }
    } else if ([cell isKindOfClass:objc_lookUpClass("YTHorizontalCardListCell")] && IS_ENABLED(HideContinueWatching)) {
        [(UICollectionView *)self deleteItemsAtIndexPaths:@[indexPath]];
    }
    return cell;
}
%end

%hook YTEngagementPanelView
- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(CopyVideoInfoPanel)) return;
    NSString *identifier = nil;
    @try {
        identifier = [[(id)self valueForKeyPath:@"panelIdentifier.identifierString"] copy];
    } @catch (NSException *exception) {}
    if (![identifier isEqualToString:@"video-description-ep-identifier"]) return;
    UIView *headerView = [self valueForKey:@"_headerView"];
    if (!headerView || [headerView viewWithTag:999]) return;

    YTQTMButton *copyInfoButton = [%c(YTQTMButton) iconButton];
    copyInfoButton.accessibilityLabel = @"Copy video info";
    copyInfoButton.tag = 999;
    [copyInfoButton setImage:YouModYTImageNamed(@"yt_outline_copy_24pt", @"doc.on.doc") forState:UIControlStateNormal];
    copyInfoButton.tintColor = UIColor.labelColor;
    copyInfoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [copyInfoButton addTarget:self action:@selector(YouModCopyDescriptionInfo:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:copyInfoButton];
    [NSLayoutConstraint activateConstraints:@[
        [copyInfoButton.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-48],
        [copyInfoButton.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        [copyInfoButton.widthAnchor constraintEqualToConstant:40.0],
        [copyInfoButton.heightAnchor constraintEqualToConstant:40.0],
    ]];
}

%new
- (void)YouModCopyDescriptionInfo:(UIButton *)sender {
    YTPlayerViewController *player = nil;
    @try {
        player = [(id)self valueForKeyPath:@"resizeDelegate.parentViewController.parentViewController.parentViewController.playerViewController"];
    } @catch (NSException *exception) {}
    NSString *title = nil;
    NSString *description = nil;
    @try {
        title = [player valueForKeyPath:@"playerResponse.playerData.videoDetails.title"];
        description = [player valueForKeyPath:@"playerResponse.playerData.videoDetails.shortDescription"];
    } @catch (NSException *exception) {}
    YTActionSheetAction *copyTitle = [%c(YTActionSheetAction) actionWithTitle:@"Copy title" iconImage:YouModYTImageNamed(@"yt_outline_text_box_24pt", @"textformat") style:0 handler:^(YTActionSheetAction *action) {
        UIPasteboard.generalPasteboard.string = title ?: @"";
        YouModShowToast(@"Copied", self);
    }];
    YTActionSheetAction *copyDescription = [%c(YTActionSheetAction) actionWithTitle:@"Copy description" iconImage:YouModYTImageNamed(@"yt_outline_message_bubble_right_24pt", @"text.bubble") style:0 handler:^(YTActionSheetAction *action) {
        UIPasteboard.generalPasteboard.string = description ?: @"";
        YouModShowToast(@"Copied", self);
    }];
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
    [sheet addAction:copyTitle];
    [sheet addAction:copyDescription];
    [sheet presentFromViewController:YouModTopViewController() animated:YES completion:nil];
}
%end

// What's all these?
%hook YTQTMButton
- (UILabel *)titleLabel {
    UILabel *label = %orig;
    if ([self.accessibilityIdentifier isEqualToString:@"id.playlist.playall.button"])
        label.adjustsFontSizeToFitWidth = YES;
    return label;
}
%end

%hook YTReelPlayerButton
- (UILabel *)titleLabel {
    UILabel *label = %orig;
    label.adjustsFontSizeToFitWidth = YES;
    return label;
}
%end

%hook YTPlaylistMiniBarView
- (void)setFrame:(CGRect)frame {
    if (frame.size.height < 54.0) frame.size.height = 54.0;
    %orig(frame);
}
%end
// --

%hook NSParagraphStyle
+ (NSWritingDirection)defaultWritingDirectionForLanguage:(id)lang { return IS_ENABLED(DisableRTL) ? NSWritingDirectionLeftToRight : %orig; }
+ (NSWritingDirection)_defaultWritingDirection { return IS_ENABLED(DisableRTL) ? NSWritingDirectionLeftToRight : %orig; }
%end

static NSURL *YouModFixedAlbumURL(NSURL *URL) {
    if (!IS_ENABLED(FixAlbums)) return URL;
    NSDictionary *replacements = @{
        @"yt3.ggpht.com": @"yt4.ggpht.com",
        @"yt3.googleusercontent.com": @"yt4.googleusercontent.com",
    };
    NSString *replacement = replacements[URL.host];
    if (!replacement) return URL;
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    components.host = replacement;
    return components.URL ?: URL;
}

%hook YTImageSelectionStrategyImageURLs
- (id)initWithSelectedImageURL:(NSURL *)selectedImageURL updatedImageURL:(NSURL *)updatedImageURL {
    return %orig(YouModFixedAlbumURL(selectedImageURL), YouModFixedAlbumURL(updatedImageURL));
}
%end

static NSString *YouModExtractShareID(GPBUnknownFieldSet *fields, int fieldNumber, NSString *format) {
    GPBUnknownField *field = [fields getField:fieldNumber];
    if (!field) return nil;
    if (field.lengthDelimitedList.count != 1) return nil;
    NSString *identifier = [[NSString alloc] initWithData:field.lengthDelimitedList.firstObject encoding:NSUTF8StringEncoding];
    return identifier.length ? [NSString stringWithFormat:format, identifier] : nil;
}

%hook ELMPBShowActionSheetCommand
- (void)executeWithCommandContext:(id)context handler:(id)handler {
    if (!IS_ENABLED(NativeShare)) return %orig;

    BOOL hasOnAppear = NO;
    id onAppear = nil;
    // These keys aren't available in the YT binary
    @try {
        hasOnAppear = [[(id)self valueForKey:@"hasOnAppear"] boolValue];
        onAppear = [(id)self valueForKey:@"onAppear"];
    } @catch (NSException *exception) {}
    if (!hasOnAppear || !onAppear) return %orig;

    id innertubeDescriptor = [NSClassFromString(@"YTIInnertubeCommandExtensionRoot") performSelector:@selector(innertubeCommand)];
    if (!innertubeDescriptor || ![onAppear hasExtension:innertubeDescriptor]) return %orig;
    id innertubeCommand = [onAppear getExtension:innertubeDescriptor];

    id updateDescriptor = [NSClassFromString(@"YTIUpdateShareSheetCommand") performSelector:@selector(updateShareSheetCommand)];
    if (!updateDescriptor || ![innertubeCommand hasExtension:updateDescriptor]) return %orig;
    id updateShareSheetCommand = [innertubeCommand getExtension:updateDescriptor];

    BOOL hasSerializedShareEntity = NO;
    NSString *serializedShareEntity = nil;
    @try {
        hasSerializedShareEntity = [[updateShareSheetCommand valueForKey:@"hasSerializedShareEntity"] boolValue];
        serializedShareEntity = [updateShareSheetCommand valueForKey:@"serializedShareEntity"];
    } @catch (NSException *exception) {}
    if (!hasSerializedShareEntity || !serializedShareEntity.length) return %orig;

    Class gpbClass = NSClassFromString(@"GPBMessage");
    GPBMessage *shareEntity = [gpbClass deserializeFromString:serializedShareEntity];
    GPBUnknownFieldSet *fields = shareEntity.unknownFields;
    NSString *shareURL = nil;

    GPBUnknownField *clipField = [fields getField:8];
    if (clipField) {
        if (clipField.lengthDelimitedList.count == 1) {
            GPBMessage *(*parse)(id, SEL, NSData *, NSError **) = (void *)objc_msgSend;
            GPBMessage *clipMessage = parse(gpbClass, @selector(parseFromData:error:), clipField.lengthDelimitedList.firstObject, nil);
            shareURL = YouModExtractShareID(clipMessage.unknownFields, 1, @"https://youtube.com/clip/%@");
        }
    }
    if (!shareURL) shareURL = YouModExtractShareID(fields, 3, @"https://youtube.com/channel/%@");
    if (!shareURL) {
        NSString *playlistID = YouModExtractShareID(fields, 2, @"%@");
        if (playlistID.length) {
            if (![playlistID hasPrefix:@"PL"] && ![playlistID hasPrefix:@"FL"])
                playlistID = [playlistID stringByAppendingString:@"&playnext=1"];
            shareURL = [@"https://youtube.com/playlist?list=" stringByAppendingString:playlistID];
        }
    }
    if (!shareURL) shareURL = YouModExtractShareID(fields, 1, @"https://youtube.com/watch?v=%@");
    if (!shareURL) return %orig;

    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[shareURL] applicationActivities:nil];
    [YouModTopViewController() presentViewController:activityViewController animated:YES completion:nil];
}
%end

%ctor {
    if (IS_ENABLED(ShortsOnlyMode) || IS_ENABLED(HideShortsTab)) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:HideShortsTab];
    }
}
