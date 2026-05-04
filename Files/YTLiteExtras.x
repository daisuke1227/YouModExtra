#import "Headers.h"
#import <Photos/Photos.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <objc/message.h>
#import <YouTubeHeader/YTDefaultSheetController.h>

@interface YTSegmentableInlinePlayerBarView : UIView
@property (nonatomic, assign, readwrite) BOOL enableSnapToChapter;
@end

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
- (void)enableNewTouchFeedback;
@end

static UIImage *YouModYTImageNamed(NSString *imageName, NSString *fallbackSystemName) {
    UIImage *image = [UIImage imageNamed:imageName inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
    if (!image && [UIImage respondsToSelector:@selector(systemImageNamed:)])
        image = [UIImage systemImageNamed:fallbackSystemName];
    return image;
}

static UIViewController *YouModTopViewController(void) {
    Class utils = NSClassFromString(@"YTUIUtils");
    if ([utils respondsToSelector:@selector(topViewControllerForPresenting)])
        return [utils topViewControllerForPresenting];
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
        if ([toastClass respondsToSelector:@selector(eventWithMessage:firstResponder:)])
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
    id overlay = [player respondsToSelector:@selector(activeVideoPlayerOverlay)] ? [player activeVideoPlayerOverlay] : nil;
    SEL setter = @selector(setPlaybackRate:);
    void (*sendRate)(id, SEL, CGFloat) = (void *)objc_msgSend;
    if ([overlay respondsToSelector:setter])
        sendRate(overlay, setter, rate);
    else if ([player respondsToSelector:setter])
        sendRate(player, setter, rate);
}

static void YouModApplyAutoQuality(YTPlayerViewController *player) {
    NSInteger qualityIndex = YouModNetworkIsCellular() ? INTFORVAL(AutoQualityCellularIndex) : INTFORVAL(AutoQualityWiFiIndex);
    if (qualityIndex == 0) return;

    id activeVideo = [player respondsToSelector:@selector(activeVideo)] ? [player activeVideo] : nil;
    NSArray *formats = [activeVideo respondsToSelector:@selector(selectableVideoFormats)] ? [activeVideo selectableVideoFormats] : nil;
    if (!formats.count) return;

    NSString *bestQualityLabel = nil;
    NSInteger highestScore = 0;
    for (MLFormat *format in formats) {
        if (![format respondsToSelector:@selector(qualityLabel)]) continue;
        NSInteger resolution = [format respondsToSelector:@selector(singleDimensionResolution)] ? [format singleDimensionResolution] : YouModQualityNumber([format qualityLabel]);
        NSInteger fps = [format respondsToSelector:@selector(FPS)] ? (NSInteger)[format FPS] : 30;
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
    if (constraint && [activeVideo respondsToSelector:setter]) {
        void (*send)(id, SEL, id) = (void *)objc_msgSend;
        send(activeVideo, setter, constraint);
    }
}

static void YouModOpenShortAsRegularVideo(YTPlayerViewController *player) {
    if (!IS_ENABLED(ShortsToRegular)) return;
    NSString *videoID = [player respondsToSelector:@selector(contentVideoID)] ? [player contentVideoID] : [player currentVideoID];
    if (!videoID.length || ![player.parentViewController isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) return;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"vnd.youtube://%@", videoID]];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

typedef NS_ENUM(NSInteger, YouModSponsorBlockAction) {
    YouModSponsorBlockActionDisable = 0,
    YouModSponsorBlockActionSkip = 1,
    YouModSponsorBlockActionAsk = 2,
    YouModSponsorBlockActionDisplay = 3,
    YouModSponsorBlockActionSkipToSegment = 4,
};

static __weak YTPlayerViewController *YouModSponsorBlockCurrentPlayer = nil;

static NSArray<NSDictionary *> *YouModSponsorBlockCategories(void) {
    return @[
        @{@"id": @"sponsor", @"title": @"Sponsor", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @0},
        @{@"id": @"selfpromo", @"title": @"Self-promotion", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @7},
        @{@"id": @"interaction", @"title": @"Interaction", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @2},
        @{@"id": @"intro", @"title": @"Intro", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @5},
        @{@"id": @"outro", @"title": @"Endcards/Credits", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @6},
        @{@"id": @"preview", @"title": @"Preview/Recap", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @4},
        @{@"id": @"music_offtopic", @"title": @"Music off-topic", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @3},
        @{@"id": @"filler", @"title": @"Filler/Jokes", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @8},
        @{@"id": @"poi_highlight", @"title": @"Highlight", @"defaultAction": @(YouModSponsorBlockActionDisplay), @"color": @4},
    ];
}

static NSDictionary *YouModSponsorBlockCategoryInfo(NSString *category) {
    for (NSDictionary *info in YouModSponsorBlockCategories()) {
        if ([info[@"id"] isEqualToString:category]) return info;
    }
    return @{@"id": category ?: @"segment", @"title": category ?: @"Segment", @"defaultAction": @(YouModSponsorBlockActionSkip), @"color": @0};
}

static NSString *YouModSponsorBlockCategoryTitle(NSString *category) {
    return YouModSponsorBlockCategoryInfo(category)[@"title"] ?: category ?: @"Segment";
}

static NSString *YouModSponsorBlockActionKey(NSString *category) {
    return [NSString stringWithFormat:@"YouModSponsorBlockAction_%@", category ?: @"segment"];
}

static NSString *YouModSponsorBlockColorKey(NSString *category) {
    return [NSString stringWithFormat:@"YouModSponsorBlockColor_%@", category ?: @"segment"];
}

static YouModSponsorBlockAction YouModSponsorBlockActionForCategory(NSString *category) {
    NSDictionary *info = YouModSponsorBlockCategoryInfo(category);
    NSString *key = YouModSponsorBlockActionKey(category);
    NSInteger action = [[NSUserDefaults standardUserDefaults] objectForKey:key] ? INTFORVAL(key) : [info[@"defaultAction"] integerValue];
    if (action < YouModSponsorBlockActionDisable || action > YouModSponsorBlockActionSkipToSegment)
        action = YouModSponsorBlockActionDisable;
    return (YouModSponsorBlockAction)action;
}

static UIColor *YouModSponsorBlockColorForCategory(NSString *category) {
    NSDictionary *info = YouModSponsorBlockCategoryInfo(category);
    NSString *key = YouModSponsorBlockColorKey(category);
    NSInteger colorIndex = [[NSUserDefaults standardUserDefaults] objectForKey:key] ? INTFORVAL(key) : [info[@"color"] integerValue];
    switch (colorIndex) {
        case 1: return [UIColor colorWithRed:0.95 green:0.20 blue:0.20 alpha:1.0];
        case 2: return [UIColor colorWithRed:1.00 green:0.55 blue:0.15 alpha:1.0];
        case 3: return [UIColor colorWithRed:1.00 green:0.86 blue:0.18 alpha:1.0];
        case 4: return [UIColor colorWithRed:0.30 green:0.80 blue:0.34 alpha:1.0];
        case 5: return [UIColor colorWithRed:0.10 green:0.72 blue:0.86 alpha:1.0];
        case 6: return [UIColor colorWithRed:0.20 green:0.45 blue:0.95 alpha:1.0];
        case 7: return [UIColor colorWithRed:0.72 green:0.32 blue:0.92 alpha:1.0];
        case 8: return [UIColor colorWithWhite:0.55 alpha:1.0];
        default: return [UIColor colorWithRed:0.00 green:0.80 blue:0.20 alpha:1.0];
    }
}

static NSMutableDictionary<NSString *, NSArray<NSDictionary *> *> *YouModSponsorBlockSegments(void) {
    static NSMutableDictionary *segments = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        segments = [NSMutableDictionary dictionary];
    });
    return segments;
}

static NSMutableSet<NSString *> *YouModSponsorBlockFetches(void) {
    static NSMutableSet *fetches = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fetches = [NSMutableSet set];
    });
    return fetches;
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
    if ([player respondsToSelector:@selector(pause)])
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

static NSString *YouModCurrentVideoID(YTPlayerViewController *player) {
    NSString *videoID = nil;
    if ([player respondsToSelector:@selector(currentVideoID)])
        videoID = [player currentVideoID];
    if (!videoID.length && [player respondsToSelector:@selector(contentVideoID)])
        videoID = [player contentVideoID];
    return videoID;
}

static CGFloat YouModCurrentMediaTime(YTPlayerViewController *player) {
    if ([player respondsToSelector:@selector(currentVideoMediaTime)])
        return [player currentVideoMediaTime];
    @try {
        return [[player valueForKey:@"currentVideoMediaTime"] doubleValue];
    } @catch (NSException *exception) {}
    return 0;
}

static CGFloat YouModCurrentTotalTime(YTPlayerViewController *player) {
    if ([player respondsToSelector:@selector(currentVideoTotalMediaTime)])
        return [player currentVideoTotalMediaTime];
    @try {
        return [[player valueForKeyPath:@"activeVideo.totalMediaTime"] doubleValue];
    } @catch (NSException *exception) {}
    return 0;
}

static NSString *YouModPercentEncode(NSString *string) {
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@":#[]@!$&'()*+,;=/?% "];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

static NSString *YouModSponsorBlockUserIDValue(void) {
    NSString *userID = [[NSUserDefaults standardUserDefaults] stringForKey:SponsorBlockUserID];
    if (userID.length >= 30) return userID;

    NSString *alphabet = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *generated = [NSMutableString stringWithCapacity:36];
    for (NSUInteger i = 0; i < 36; i++) {
        uint32_t index = arc4random_uniform((uint32_t)alphabet.length);
        [generated appendString:[alphabet substringWithRange:NSMakeRange(index, 1)]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:generated forKey:SponsorBlockUserID];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return generated;
}

static void YouModSponsorBlockPOST(NSString *endpoint, NSDictionary *query, id jsonBody, void (^completion)(BOOL ok, NSString *message, id json)) {
    NSMutableArray *parts = [NSMutableArray array];
    [query enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [parts addObject:[NSString stringWithFormat:@"%@=%@", YouModPercentEncode([key description]), YouModPercentEncode([obj description])]];
    }];
    NSString *URLString = [NSString stringWithFormat:@"https://sponsor.ajay.app/api/%@%@", endpoint, parts.count ? [@"?" stringByAppendingString:[parts componentsJoinedByString:@"&"]] : @""];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"YouMod/1.2.3" forHTTPHeaderField:@"User-Agent"];
    if (jsonBody) {
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:nil];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *body = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        BOOL ok = http.statusCode >= 200 && http.statusCode < 300 && !error;
        NSString *message = ok ? @"Done" : (body.length ? body : (error.localizedDescription ?: [NSString stringWithFormat:@"SponsorBlock HTTP %ld", (long)http.statusCode]));
        if (completion) completion(ok, message, json);
    }] resume];
}

static void YouModSponsorBlockReportViewed(NSDictionary *segment) {
    NSString *uuid = segment[@"uuid"];
    if (!uuid.length) return;
    YouModSponsorBlockPOST(@"viewedVideoSponsorTime", @{@"UUID": uuid}, nil, nil);
}

static NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *YouModSponsorBlockPromptedSegments(void) {
    static NSMutableDictionary *prompted = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prompted = [NSMutableDictionary dictionary];
    });
    return prompted;
}

static void YouModSponsorBlockFetchIfNeeded(YTPlayerViewController *player) {
    if (!IS_ENABLED(SponsorBlockEnabled)) return;
    NSString *videoID = YouModCurrentVideoID(player);
    if (!videoID.length) return;

    NSMutableDictionary *segments = YouModSponsorBlockSegments();
    NSMutableSet *fetches = YouModSponsorBlockFetches();
    @synchronized (segments) {
        if (segments[videoID] || [fetches containsObject:videoID]) return;
        [fetches addObject:videoID];
    }

    NSMutableArray *categories = [NSMutableArray array];
    for (NSDictionary *categoryInfo in YouModSponsorBlockCategories()) {
        NSString *category = categoryInfo[@"id"];
        if (YouModSponsorBlockActionForCategory(category) != YouModSponsorBlockActionDisable)
            [categories addObject:category];
    }
    if (!categories.count) {
        @synchronized (segments) {
            segments[videoID] = @[];
            [fetches removeObject:videoID];
        }
        return;
    }
    NSData *categoryData = [NSJSONSerialization dataWithJSONObject:categories options:0 error:nil];
    NSData *actionTypeData = [NSJSONSerialization dataWithJSONObject:@[@"skip", @"poi"] options:0 error:nil];
    NSString *categoryString = [[NSString alloc] initWithData:categoryData encoding:NSUTF8StringEncoding] ?: @"[]";
    NSString *actionTypeString = [[NSString alloc] initWithData:actionTypeData encoding:NSUTF8StringEncoding] ?: @"[]";
    NSMutableCharacterSet *allowedCharacters = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowedCharacters removeCharactersInString:@"[]\" "];
    NSString *encodedCategories = [categoryString stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    NSString *encodedActionTypes = [actionTypeString stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    NSString *URLString = [NSString stringWithFormat:@"https://sponsor.ajay.app/api/skipSegments?videoID=%@&categories=%@&actionTypes=%@", YouModPercentEncode(videoID), encodedCategories, encodedActionTypes];
    NSURL *URL = [NSURL URLWithString:URLString];
    if (!URL) return;

    [[NSURLSession.sharedSession dataTaskWithURL:URL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *parsedSegments = @[];
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        if (data.length && http.statusCode != 404) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:NSArray.class]) {
                NSMutableArray *cleanSegments = [NSMutableArray array];
                for (NSDictionary *entry in (NSArray *)json) {
                    NSArray *segment = [entry[@"segment"] isKindOfClass:NSArray.class] ? entry[@"segment"] : nil;
                    NSString *category = entry[@"category"] ?: @"segment";
                    if (segment.count >= 2 && YouModSponsorBlockActionForCategory(category) != YouModSponsorBlockActionDisable) {
                        [cleanSegments addObject:@{
                            @"start": segment[0],
                            @"end": segment[1],
                            @"category": category,
                            @"uuid": entry[@"UUID"] ?: @"",
                            @"actionType": entry[@"actionType"] ?: @"skip",
                            @"votes": entry[@"votes"] ?: @0,
                            @"description": entry[@"description"] ?: @"",
                        }];
                    }
                }
                parsedSegments = [cleanSegments sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                    return [a[@"start"] compare:b[@"start"]];
                }];
            }
        }
        @synchronized (segments) {
            segments[videoID] = parsedSegments ?: @[];
            [fetches removeObject:videoID];
        }
    }] resume];
}

void YouModApplyYTLitePlaybackDefaults(YTPlayerViewController *player) {
    if (!player) return;
    YouModSponsorBlockCurrentPlayer = player;
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
    YouModSponsorBlockFetchIfNeeded(player);
}

static NSString *YouModSponsorBlockTimeString(NSTimeInterval time) {
    NSInteger seconds = MAX(0, (NSInteger)llround(time));
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
}

static void YouModSponsorBlockSeek(YTPlayerViewController *player, NSTimeInterval time) {
    SEL seekSelector = @selector(seekToTime:);
    if ([player respondsToSelector:seekSelector]) {
        void (*seek)(id, SEL, CGFloat) = (void *)objc_msgSend;
        seek(player, seekSelector, time);
    }
}

static void YouModSponsorBlockCompleteSkip(YTPlayerViewController *player, NSDictionary *segment, NSTimeInterval targetTime, NSString *message) {
    if (!player || !segment) return;
    YouModSponsorBlockSeek(player, targetTime);
    objc_setAssociatedObject(player, @selector(YouModSponsorBlockCompleteSkip), segment, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    YouModSponsorBlockReportViewed(segment);
    if (IS_ENABLED(SponsorBlockNotifications))
        YouModShowToast(message, player);
}

static void YouModSponsorBlockPrompt(YTPlayerViewController *player, NSDictionary *segment, BOOL jumpToStart) {
    NSString *uuid = segment[@"uuid"] ?: [NSString stringWithFormat:@"%@:%@:%@", segment[@"category"], segment[@"start"], segment[@"end"]];
    NSString *videoID = YouModCurrentVideoID(player) ?: @"";
    NSMutableDictionary *prompted = YouModSponsorBlockPromptedSegments();
    @synchronized (prompted) {
        NSMutableSet *set = prompted[videoID];
        if (!set) {
            set = [NSMutableSet set];
            prompted[videoID] = set;
        }
        if ([set containsObject:uuid]) return;
        [set addObject:uuid];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *title = YouModSponsorBlockCategoryTitle(segment[@"category"]);
        YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:jumpToStart ? [NSString stringWithFormat:@"Jump to %@", title] : [NSString stringWithFormat:@"Skip %@", title] iconImage:YouModYTImageNamed(@"yt_outline_fast_forward_24pt", @"forward.end") style:0 handler:^(YTActionSheetAction *action) {
            NSTimeInterval target = jumpToStart ? [segment[@"start"] doubleValue] : [segment[@"end"] doubleValue];
            YouModSponsorBlockCompleteSkip(player, segment, target, jumpToStart ? [NSString stringWithFormat:@"Jumped to %@", title] : [NSString stringWithFormat:@"Skipped %@", title]);
        }]];
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Ignore" iconImage:YouModYTImageNamed(@"yt_outline_close_24pt", @"xmark") style:0 handler:^(__unused YTActionSheetAction *action) {}]];
        [sheet presentFromViewController:YouModTopViewController() animated:YES completion:nil];
    });
}

static void YouModSponsorBlockHandleTime(YTPlayerViewController *player, NSTimeInterval currentTime) {
    if (!IS_ENABLED(SponsorBlockEnabled)) return;
    NSString *videoID = YouModCurrentVideoID(player);
    NSArray *segments = videoID.length ? YouModSponsorBlockSegments()[videoID] : nil;
    if (!segments) {
        YouModSponsorBlockFetchIfNeeded(player);
        return;
    }

    for (NSDictionary *segment in segments) {
        NSString *category = segment[@"category"];
        YouModSponsorBlockAction action = YouModSponsorBlockActionForCategory(category);
        if (action == YouModSponsorBlockActionDisable) continue;

        NSTimeInterval start = [segment[@"start"] doubleValue];
        NSTimeInterval end = [segment[@"end"] doubleValue];
        NSString *actionType = segment[@"actionType"] ?: @"skip";
        BOOL isHighlight = [category isEqualToString:@"poi_highlight"] || [actionType isEqualToString:@"poi"];
        NSString *title = YouModSponsorBlockCategoryTitle(category);

        if (isHighlight) {
            if (currentTime < start - 0.5 && currentTime > 1.0 && (action == YouModSponsorBlockActionSkip || action == YouModSponsorBlockActionSkipToSegment)) {
                NSString *skipKey = [NSString stringWithFormat:@"%@:%@:poi", videoID ?: @"", segment[@"uuid"] ?: segment[@"start"]];
                NSString *lastSkipKey = objc_getAssociatedObject(player, @selector(YouModSponsorBlockHandleTime));
                if ([skipKey isEqualToString:lastSkipKey]) continue;
                objc_setAssociatedObject(player, @selector(YouModSponsorBlockHandleTime), skipKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
                YouModSponsorBlockCompleteSkip(player, segment, start, [NSString stringWithFormat:@"Jumped to %@", title]);
                return;
            }
            if (action == YouModSponsorBlockActionAsk && currentTime < start - 0.5 && currentTime > 1.0) {
                YouModSponsorBlockPrompt(player, segment, YES);
                return;
            }
            continue;
        }

        if (end <= start) continue;
        if (currentTime >= start && currentTime < end - 0.25) {
            NSString *skipKey = [NSString stringWithFormat:@"%@:%@:%.3f", videoID ?: @"", segment[@"uuid"] ?: category, end];
            NSString *lastSkipKey = objc_getAssociatedObject(player, @selector(YouModSponsorBlockFetchIfNeeded));
            if ([skipKey isEqualToString:lastSkipKey]) return;
            objc_setAssociatedObject(player, @selector(YouModSponsorBlockFetchIfNeeded), skipKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
            if (action == YouModSponsorBlockActionSkip) {
                YouModSponsorBlockCompleteSkip(player, segment, end, [NSString stringWithFormat:@"Skipped %@", title]);
                return;
            }
            if (action == YouModSponsorBlockActionAsk) {
                YouModSponsorBlockPrompt(player, segment, NO);
                return;
            }
        } else if (IS_ENABLED(SponsorBlockNotifications) && currentTime >= start - 0.25 && currentTime < start + 0.25 && action == YouModSponsorBlockActionDisplay) {
            NSString *displayKey = [NSString stringWithFormat:@"%@:%@:display", videoID ?: @"", segment[@"uuid"] ?: category];
            NSString *lastDisplayKey = objc_getAssociatedObject(player, @selector(YouModSponsorBlockActionForCategory));
            if (![displayKey isEqualToString:lastDisplayKey]) {
                objc_setAssociatedObject(player, @selector(YouModSponsorBlockActionForCategory), displayKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
                YouModShowToast([NSString stringWithFormat:@"%@ detected", title], player);
            }
        }
    }
}

static void YouModSponsorBlockVote(YTPlayerViewController *player, NSDictionary *segment, NSInteger voteType) {
    NSString *uuid = segment[@"uuid"];
    if (!uuid.length) {
        YouModShowToast(@"SponsorBlock UUID missing", player);
        return;
    }
    NSMutableDictionary *query = [@{@"UUID": uuid, @"userID": YouModSponsorBlockUserIDValue(), @"type": @(voteType)} mutableCopy];
    NSString *videoID = YouModCurrentVideoID(player);
    if (videoID.length) query[@"videoID"] = videoID;
    YouModSponsorBlockPOST(@"voteOnSponsorTime", query, nil, ^(BOOL ok, NSString *message, id json) {
        YouModShowToast(ok ? @"SponsorBlock vote sent" : message, player);
    });
}

static void YouModSponsorBlockChangeCategory(YTPlayerViewController *player, NSDictionary *segment, NSString *category) {
    NSString *uuid = segment[@"uuid"];
    if (!uuid.length || !category.length) return;
    YouModSponsorBlockPOST(@"voteOnSponsorTime", @{@"UUID": uuid, @"userID": YouModSponsorBlockUserIDValue(), @"category": category}, nil, ^(BOOL ok, NSString *message, id json) {
        YouModShowToast(ok ? @"SponsorBlock category vote sent" : message, player);
    });
}

static void YouModSponsorBlockDeleteSegment(YTPlayerViewController *player, NSDictionary *segment) {
    NSString *uuid = segment[@"uuid"];
    if (!uuid.length) {
        YouModShowToast(@"No UUID to delete", player);
        return;
    }
    NSString *videoID = YouModCurrentVideoID(player);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete segment?" message:@"This downvotes your own segment to remove it. This cannot be undone." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSMutableDictionary *query = [@{@"UUID": uuid, @"userID": YouModSponsorBlockUserIDValue(), @"type": @0} mutableCopy];
        if (videoID.length) query[@"videoID"] = videoID;
        YouModSponsorBlockPOST(@"voteOnSponsorTime", query, nil, ^(BOOL ok, NSString *message, __unused id json) {
            if (ok && videoID.length) {
                @synchronized (YouModSponsorBlockSegments()) {
                    [YouModSponsorBlockSegments() removeObjectForKey:videoID];
                }
                YouModSponsorBlockFetchIfNeeded(player);
            }
            YouModShowToast(ok ? @"Segment deleted" : message, player);
        });
    }]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [YouModTopViewController() presentViewController:alert animated:YES completion:nil];
    });
}

static NSTimeInterval YouModParseTimeString(NSString *text) {
    NSArray *parts = [text componentsSeparatedByString:@":"];
    if (parts.count == 2)
        return [parts[0] doubleValue] * 60.0 + [parts[1] doubleValue];
    if (parts.count == 3)
        return [parts[0] doubleValue] * 3600.0 + [parts[1] doubleValue] * 60.0 + [parts[2] doubleValue];
    return [text doubleValue];
}

static NSString *YouModSponsorBlockPreciseTimeString(NSTimeInterval time) {
    NSInteger totalSeconds = (NSInteger)time;
    NSInteger frac = (NSInteger)((time - totalSeconds) * 1000);
    return frac > 0
        ? [NSString stringWithFormat:@"%ld:%02ld.%03ld", (long)(totalSeconds / 60), (long)(totalSeconds % 60), (long)frac]
        : [NSString stringWithFormat:@"%ld:%02ld", (long)(totalSeconds / 60), (long)(totalSeconds % 60)];
}

static void YouModSponsorBlockEditSegment(YTPlayerViewController *player, NSDictionary *segment) {
    NSString *uuid = segment[@"uuid"];
    if (!uuid.length) {
        YouModShowToast(@"No UUID to edit", player);
        return;
    }
    NSString *videoID = YouModCurrentVideoID(player);
    if (!videoID.length) return;

    NSTimeInterval oldStart = [segment[@"start"] doubleValue];
    NSTimeInterval oldEnd = [segment[@"end"] doubleValue];
    NSString *category = segment[@"category"] ?: @"sponsor";
    NSString *actionType = segment[@"actionType"] ?: @"skip";
    BOOL isHighlight = [category isEqualToString:@"poi_highlight"] || [actionType isEqualToString:@"poi"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Edit segment" message:@"Adjust start/end times then submit. This removes the old segment and submits a new one." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Start (m:ss or m:ss.ms)";
        tf.text = YouModSponsorBlockPreciseTimeString(oldStart);
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    if (!isHighlight) {
        [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"End (m:ss or m:ss.ms)";
            tf.text = YouModSponsorBlockPreciseTimeString(oldEnd);
            tf.keyboardType = UIKeyboardTypeDecimalPad;
        }];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSTimeInterval newStart = YouModParseTimeString(alert.textFields.firstObject.text);
        NSTimeInterval newEnd = isHighlight ? newStart : YouModParseTimeString(alert.textFields.lastObject.text);
        if (!isHighlight && newEnd - newStart < 0.5) {
            YouModShowToast(@"Segment must be at least 0.5 seconds", player);
            return;
        }

        // step 1: downvote the old segment
        NSMutableDictionary *deleteQuery = [@{@"UUID": uuid, @"userID": YouModSponsorBlockUserIDValue(), @"type": @0} mutableCopy];
        if (videoID.length) deleteQuery[@"videoID"] = videoID;
        YouModSponsorBlockPOST(@"voteOnSponsorTime", deleteQuery, nil, ^(BOOL delOk, NSString *delMsg, __unused id delJson) {
            if (!delOk) {
                YouModShowToast([NSString stringWithFormat:@"Delete failed: %@", delMsg], player);
                return;
            }

            // step 2: submit the corrected segment
            NSDictionary *seg = @{
                @"segment": isHighlight ? @[@(newStart), @(newStart)] : @[@(newStart), @(newEnd)],
                @"category": category,
                @"actionType": actionType,
                @"description": @"",
            };
            NSDictionary *body = @{
                @"videoID": videoID,
                @"userID": YouModSponsorBlockUserIDValue(),
                @"userAgent": @"YouMod/1.2.3",
                @"service": @"YouTube",
                @"videoDuration": @(YouModCurrentTotalTime(player)),
                @"segments": @[seg],
            };
            YouModSponsorBlockPOST(@"skipSegments", @{}, body, ^(BOOL subOk, NSString *subMsg, __unused id subJson) {
                if (subOk) {
                    @synchronized (YouModSponsorBlockSegments()) {
                        [YouModSponsorBlockSegments() removeObjectForKey:videoID];
                    }
                    YouModSponsorBlockFetchIfNeeded(player);
                }
                YouModShowToast(subOk ? @"Segment edited" : [NSString stringWithFormat:@"Submit failed: %@", subMsg], player);
            });
        });
    }]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [YouModTopViewController() presentViewController:alert animated:YES completion:nil];
    });
}

static void YouModSponsorBlockPresentCategoryChangeSheet(YTPlayerViewController *player, NSDictionary *segment) {
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
    for (NSDictionary *category in YouModSponsorBlockCategories()) {
        NSString *categoryID = category[@"id"];
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:category[@"title"] iconImage:YouModYTImageNamed(@"yt_outline_flag_24pt", @"tag") style:0 handler:^(__unused YTActionSheetAction *action) {
            YouModSponsorBlockChangeCategory(player, segment, categoryID);
        }]];
    }
    [sheet presentFromViewController:YouModTopViewController() animated:YES completion:nil];
}

static void YouModSponsorBlockPresentSegmentSheet(YTPlayerViewController *player, NSDictionary *segment) {
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
    NSString *title = YouModSponsorBlockCategoryTitle(segment[@"category"]);
    NSTimeInterval start = [segment[@"start"] doubleValue];
    NSTimeInterval end = [segment[@"end"] doubleValue];
    NSString *range = [NSString stringWithFormat:@"%@ - %@", YouModSponsorBlockTimeString(start), YouModSponsorBlockTimeString(end)];

    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:[NSString stringWithFormat:@"Jump to %@", range] iconImage:YouModYTImageNamed(@"yt_outline_play_arrow_24pt", @"play") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockSeek(player, start);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:[NSString stringWithFormat:@"Skip %@", title] iconImage:YouModYTImageNamed(@"yt_outline_fast_forward_24pt", @"forward.end") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockCompleteSkip(player, segment, end > start ? end : start, [NSString stringWithFormat:@"Skipped %@", title]);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Edit segment" iconImage:YouModYTImageNamed(@"yt_outline_edit_24pt", @"pencil") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockEditSegment(player, segment);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Delete segment" iconImage:YouModYTImageNamed(@"yt_outline_trash_24pt", @"trash") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockDeleteSegment(player, segment);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Upvote segment" iconImage:YouModYTImageNamed(@"yt_outline_like_24pt", @"hand.thumbsup") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockVote(player, segment, 1);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Downvote segment" iconImage:YouModYTImageNamed(@"yt_outline_dislike_24pt", @"hand.thumbsdown") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockVote(player, segment, 0);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Undo vote" iconImage:YouModYTImageNamed(@"yt_outline_undo_24pt", @"arrow.uturn.backward") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockVote(player, segment, 20);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Change category vote" iconImage:YouModYTImageNamed(@"yt_outline_flag_24pt", @"flag") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockPresentCategoryChangeSheet(player, segment);
    }]];
    if ([segment[@"uuid"] length]) {
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Copy UUID" iconImage:YouModYTImageNamed(@"yt_outline_copy_24pt", @"doc.on.doc") style:0 handler:^(__unused YTActionSheetAction *action) {
            UIPasteboard.generalPasteboard.string = segment[@"uuid"];
            YouModShowToast(@"Copied", player);
        }]];
    }
    [sheet presentFromViewController:YouModTopViewController() animated:YES completion:nil];
}

static void YouModSponsorBlockSubmitSegment(YTPlayerViewController *player, NSString *category) {
    NSNumber *draftStart = objc_getAssociatedObject(player, @selector(YouModSponsorBlockSubmitSegment));
    CGFloat start = draftStart.doubleValue;
    CGFloat end = YouModCurrentMediaTime(player);
    if (end < start) {
        CGFloat swap = start;
        start = end;
        end = swap;
    }
    BOOL isHighlight = [category isEqualToString:@"poi_highlight"];
    if (!isHighlight && end - start < 0.5) {
        YouModShowToast(@"Mark a longer segment first", player);
        return;
    }

    NSString *videoID = YouModCurrentVideoID(player);
    if (!videoID.length) return;
    NSDictionary *segment = @{
        @"segment": isHighlight ? @[@(start), @(start)] : @[@(start), @(end)],
        @"category": category,
        @"actionType": isHighlight ? @"poi" : @"skip",
        @"description": @"",
    };
    NSDictionary *body = @{
        @"videoID": videoID,
        @"userID": YouModSponsorBlockUserIDValue(),
        @"userAgent": @"YouMod/1.2.3",
        @"service": @"YouTube",
        @"videoDuration": @(YouModCurrentTotalTime(player)),
        @"segments": @[segment],
    };
    YouModSponsorBlockPOST(@"skipSegments", @{}, body, ^(BOOL ok, NSString *message, id json) {
        if (ok) {
            @synchronized (YouModSponsorBlockSegments()) {
                [YouModSponsorBlockSegments() removeObjectForKey:videoID];
            }
            YouModSponsorBlockFetchIfNeeded(player);
        }
        YouModShowToast(ok ? @"SponsorBlock segment submitted" : message, player);
    });
}

static void YouModSponsorBlockPresentSubmitCategorySheet(YTPlayerViewController *player) {
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
    for (NSDictionary *category in YouModSponsorBlockCategories()) {
        NSString *categoryID = category[@"id"];
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:category[@"title"] iconImage:YouModYTImageNamed(@"yt_outline_flag_24pt", @"tag") style:0 handler:^(__unused YTActionSheetAction *action) {
            YouModSponsorBlockSubmitSegment(player, categoryID);
        }]];
    }
    [sheet presentFromViewController:YouModTopViewController() animated:YES completion:nil];
}

static void YouModSponsorBlockPresentSheet(YTPlayerViewController *player) {
    if (!player) player = YouModSponsorBlockCurrentPlayer;
    if (!player) return;
    NSString *videoID = YouModCurrentVideoID(player);
    NSArray *segments = videoID.length ? YouModSponsorBlockSegments()[videoID] : nil;

    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Refresh segments" iconImage:YouModYTImageNamed(@"yt_outline_refresh_24pt", @"arrow.clockwise") style:0 handler:^(__unused YTActionSheetAction *action) {
        if (videoID.length) {
            @synchronized (YouModSponsorBlockSegments()) {
                [YouModSponsorBlockSegments() removeObjectForKey:videoID];
            }
        }
        YouModSponsorBlockFetchIfNeeded(player);
        YouModShowToast(@"SponsorBlock refresh started", player);
    }]];
    NSDictionary *lastSkipped = objc_getAssociatedObject(player, @selector(YouModSponsorBlockCompleteSkip));
    if (lastSkipped) {
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Unskip last segment" iconImage:YouModYTImageNamed(@"yt_outline_undo_24pt", @"arrow.uturn.backward") style:0 handler:^(__unused YTActionSheetAction *action) {
            YouModSponsorBlockSeek(player, [lastSkipped[@"start"] doubleValue]);
        }]];
    }
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Mark segment start" iconImage:YouModYTImageNamed(@"yt_outline_add_circle_24pt", @"plus.circle") style:0 handler:^(__unused YTActionSheetAction *action) {
        objc_setAssociatedObject(player, @selector(YouModSponsorBlockSubmitSegment), @(YouModCurrentMediaTime(player)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        YouModShowToast(@"SponsorBlock start marked", player);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:@"Submit marked segment" iconImage:YouModYTImageNamed(@"yt_outline_upload_24pt", @"square.and.arrow.up") style:0 handler:^(__unused YTActionSheetAction *action) {
        YouModSponsorBlockPresentSubmitCategorySheet(player);
    }]];

    if (segments.count) {
        for (NSDictionary *segment in segments) {
            NSString *title = YouModSponsorBlockCategoryTitle(segment[@"category"]);
            NSString *range = [NSString stringWithFormat:@"%@ - %@", YouModSponsorBlockTimeString([segment[@"start"] doubleValue]), YouModSponsorBlockTimeString([segment[@"end"] doubleValue])];
            NSString *rowTitle = [NSString stringWithFormat:@"%@ %@", title, range];
            [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:rowTitle iconImage:YouModYTImageNamed(@"yt_outline_flag_24pt", @"flag") style:0 handler:^(__unused YTActionSheetAction *action) {
                YouModSponsorBlockPresentSegmentSheet(player, segment);
            }]];
        }
    }
    [sheet presentFromViewController:YouModTopViewController() animated:YES completion:nil];
}

static NSString *YouModEndTimeStringForVideo(YTSingleVideoController *video, YTSingleVideoTime *time) {
    CGFloat totalTime = 0;
    @try {
        totalTime = [[video valueForKey:@"totalMediaTime"] doubleValue];
    } @catch (NSException *exception) {
        if ([video respondsToSelector:@selector(totalMediaTime)])
            totalTime = video.totalMediaTime;
    }
    if (totalTime <= 0 || time.time < 0) return nil;

    CGFloat rate = 1.0;
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
    YouModSponsorBlockCurrentPlayer = player;
    YouModSponsorBlockHandleTime(player, time.time);

    if (YouModSleepTimerAtEndOfVideo) {
        CGFloat totalTime = 0;
        @try {
            totalTime = [[video valueForKey:@"totalMediaTime"] doubleValue];
        } @catch (NSException *exception) {}
        if (totalTime > 0 && totalTime - time.time <= 1.0)
            YouModPauseForSleepTimer();
    }

    if (IS_ENABLED(VideoEndTime)) {
        NSString *endTime = YouModEndTimeStringForVideo(video, time);
        YTPlayerView *playerView = [player respondsToSelector:@selector(playerView)] ? [player playerView] : (YTPlayerView *)player.view;
        UIView *overlayView = [playerView respondsToSelector:@selector(overlayView)] ? playerView.overlayView : nil;
        if ([overlayView isKindOfClass:NSClassFromString(@"YTMainAppVideoPlayerOverlayView")]) {
            YTInlinePlayerBarContainerView *playerBar = [(YTMainAppVideoPlayerOverlayView *)overlayView playerBar];
            YTLabel *durationLabel = playerBar.durationLabel;
            if (endTime.length && durationLabel.text.length && ![durationLabel.text containsString:endTime]) {
                objc_setAssociatedObject(playerBar, @selector(YouModEndTimeStringForVideo), endTime, OBJC_ASSOCIATION_COPY_NONATOMIC);
                durationLabel.text = [durationLabel.text stringByAppendingFormat:@" - %@", endTime];
                [durationLabel sizeToFit];
            }
        }
    }

    if (IS_ENABLED(AutoSkipShorts)) {
        CGFloat totalTime = 0;
        @try {
            totalTime = [[video valueForKey:@"totalMediaTime"] doubleValue];
        } @catch (NSException *exception) {}
        if (totalTime > 0 && floor(time.time) >= floor(totalTime) && [player.parentViewController isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) {
            SEL advance = @selector(reelContentViewRequestsAdvanceToNextVideo:);
            if ([player.parentViewController respondsToSelector:advance]) {
                void (*send)(id, SEL, id) = (void *)objc_msgSend;
                send(player.parentViewController, advance, nil);
            }
        }
    }
}

%hook YTHUDMessageView
- (id)initWithMessage:(id)arg1 dismissHandler:(id)arg2 { return IS_ENABLED(NoHUDMessages) ? nil : %orig; }
%end

%hook YTColdConfig
- (BOOL)videoZoomFreeZoomEnabledGlobalConfig { return IS_ENABLED(NoFreeZoom) ? NO : %orig; }
- (BOOL)enableHideChipsInTheCommentsHeaderOnScrollIos { return IS_ENABLED(StickSortComments) ? NO : %orig; }
- (BOOL)enableChipsInTheCommentsHeaderIos { return IS_ENABLED(HideSortComments) ? NO : %orig; }
- (BOOL)queueClientGlobalConfigEnableFloatingPlaylistMinibar { return IS_ENABLED(PlaylistOldMinibar) ? NO : %orig; }
- (BOOL)iosUseSystemVolumeControlInFullscreen { return IS_ENABLED(StockVolumeHUD) ? YES : %orig; }
%end

static const NSInteger YouModSponsorBlockMarkerTag = 732041;

static BOOL YouModSponsorBlockViewIsVisible(UIView *view, UIView *root) {
    if (!view || !root || view.hidden || view.alpha <= 0.03 || CGRectIsEmpty(view.bounds)) return NO;
    for (UIView *cursor = view.superview; cursor && cursor != root; cursor = cursor.superview) {
        if (cursor.hidden || cursor.alpha <= 0.03) return NO;
    }
    return YES;
}

static void YouModSponsorBlockRemoveMarkers(UIView *view) {
    for (UIView *subview in [view.subviews copy]) {
        if (subview.tag == YouModSponsorBlockMarkerTag) {
            [subview removeFromSuperview];
            continue;
        }
        YouModSponsorBlockRemoveMarkers(subview);
    }
}

static void YouModSponsorBlockFindTrackCandidate(UIView *view, UIView *root, UIView **bestView, CGFloat *bestScore) {
    if (view.tag == YouModSponsorBlockMarkerTag) return;
    if (view != root && YouModSponsorBlockViewIsVisible(view, root)) {
        CGRect frame = [view convertRect:view.bounds toView:root];
        CGFloat width = CGRectGetWidth(frame);
        CGFloat height = CGRectGetHeight(frame);
        BOOL thinTrack = width >= 80.0 && height >= 1.0 && height <= 8.0;
        BOOL insideRoot = CGRectIntersectsRect(root.bounds, frame);
        BOOL likelyControl = [view isKindOfClass:UIControl.class] || [view isKindOfClass:UILabel.class];
        if (thinTrack && insideRoot && !likelyControl) {
            CGFloat score = width - (fabs(CGRectGetMidY(frame) - CGRectGetMidY(root.bounds)) * 0.05);
            if (!*bestView || score > *bestScore) {
                *bestView = view;
                *bestScore = score;
            }
        }
    }

    for (UIView *subview in view.subviews) {
        YouModSponsorBlockFindTrackCandidate(subview, root, bestView, bestScore);
    }
}

static UIView *YouModSponsorBlockFindTrack(YTInlinePlayerBarContainerView *bar) {
    if (!YouModSponsorBlockViewIsVisible(bar, bar)) return nil;

    UIView *trackView = nil;
    CGFloat bestScore = -CGFLOAT_MAX;
    YouModSponsorBlockFindTrackCandidate(bar, bar, &trackView, &bestScore);
    if (!trackView) return nil;

    CGRect frame = [trackView convertRect:trackView.bounds toView:bar];
    if (CGRectGetWidth(frame) < 80.0 || CGRectGetHeight(frame) < 1.0) return nil;
    return trackView;
}

%hook YTInlinePlayerBarContainerView
- (void)layoutSubviews {
    %orig;
    YouModSponsorBlockRemoveMarkers(self);
    if (!IS_ENABLED(SponsorBlockEnabled) || !IS_ENABLED(SponsorBlockSegmentMarkers)) return;

    UIView *trackView = YouModSponsorBlockFindTrack(self);
    if (!trackView) return;

    UIView *fadeView = trackView;
    while (fadeView.superview && fadeView.superview != self) {
        fadeView = fadeView.superview;
    }

    YTPlayerViewController *player = YouModSponsorBlockCurrentPlayer;
    NSString *videoID = YouModCurrentVideoID(player);
    NSArray *segments = videoID.length ? YouModSponsorBlockSegments()[videoID] : nil;
    CGFloat totalTime = YouModCurrentTotalTime(player);
    if (!segments.count || totalTime <= 0.0) return;

    CGRect trackFrame = [trackView convertRect:trackView.bounds toView:fadeView];
    CGFloat trackWidth = CGRectGetWidth(trackFrame);
    CGFloat markerHeight = CGRectGetHeight(trackFrame);
    CGFloat y = CGRectGetMinY(trackFrame);
    CGFloat minX = CGRectGetMinX(trackFrame);
    
    for (NSDictionary *segment in segments) {
        NSString *category = segment[@"category"];
        if (YouModSponsorBlockActionForCategory(category) == YouModSponsorBlockActionDisable) continue;
        CGFloat start = [segment[@"start"] doubleValue];
        CGFloat end = [segment[@"end"] doubleValue];
        if (end <= start) end = start + MAX(1.0, totalTime * 0.004);

        CGFloat x = minX + MAX(0.0, MIN(trackWidth, trackWidth * (start / totalTime)));
        CGFloat width = MAX(2.0, MIN(trackWidth - (x - minX), trackWidth * ((end - start) / totalTime)));
        if (width <= 0.0) continue;

        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, markerHeight)];
        marker.tag = YouModSponsorBlockMarkerTag;
        marker.userInteractionEnabled = NO;
        marker.backgroundColor = YouModSponsorBlockColorForCategory(category);
        [fadeView addSubview:marker];
    }
}

- (void)setPeekableViewVisible:(BOOL)visible {
    %orig;
    if (!IS_ENABLED(VideoEndTime)) return;
    NSString *endTime = objc_getAssociatedObject(self, @selector(YouModEndTimeStringForVideo));
    if (endTime.length && self.durationLabel.text.length && ![self.durationLabel.text containsString:endTime]) {
        self.durationLabel.text = [self.durationLabel.text stringByAppendingFormat:@" - %@", endTime];
        [self.durationLabel sizeToFit];
    }
}

- (id)quietProgressBarColor { return IS_ENABLED(RedProgressBar) ? [UIColor redColor] : %orig; }
%end

%hook YTSegmentableInlinePlayerBarView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(DontSnapToChapter) && [self respondsToSelector:@selector(setEnableSnapToChapter:)])
        self.enableSnapToChapter = NO;
}

- (void)setBufferedProgressBarColor:(id)arg1 {
    IS_ENABLED(RedProgressBar) ? %orig([UIColor colorWithRed:0.65 green:0.65 blue:0.65 alpha:0.60]) : %orig;
}
%end

%hook YTModularPlayerBarController
- (void)setEnableSnapToChapter:(BOOL)arg1 { IS_ENABLED(DontSnapToChapter) ? %orig(NO) : %orig; }
%end

%hook YTMainAppVideoPlayerOverlayViewController
- (void)didPressPause:(id)sender {
    %orig;
    if (!IS_ENABLED(CopyWithTimestamp)) return;
    NSString *videoID = nil;
    CGFloat mediaTime = 0;
    @try {
        videoID = [self valueForKey:@"videoID"];
        mediaTime = [[self valueForKey:@"mediaTime"] doubleValue];
    } @catch (NSException *exception) {}
    if (videoID.length)
        UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@&t=%lds", videoID, (long)mediaTime];
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
    UILabel *label = nil;
    @try {
        label = [educationView valueForKey:@"_userEducationLabel"];
    } @catch (NSException *exception) {}
    if (label) {
        educationView.labelType = 1;
        label.text = [NSString stringWithFormat:@"Playback speed: %.2gx", speed];
    }

    if (gesture.state == UIGestureRecognizerStateBegan) {
        YouModRateBeforeHoldToSpeed = [delegate respondsToSelector:@selector(currentPlaybackRate)] ? [delegate currentPlaybackRate] : 1.0;
        [delegate setPlaybackRate:speed];
        [educationView setVisible:YES];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        [delegate setPlaybackRate:YouModRateBeforeHoldToSpeed];
        [educationView setVisible:NO];
    }
}

%hook YTMainAppVideoPlayerOverlayView
- (void)layoutSubviews {
    %orig;
    UIButton *button = objc_getAssociatedObject(self, @selector(YouModSponsorBlockButtonTapped:));
    if (!IS_ENABLED(SponsorBlockEnabled) || !IS_ENABLED(SponsorBlockPlayerButton)) {
        [button removeFromSuperview];
        objc_setAssociatedObject(self, @selector(YouModSponsorBlockButtonTapped:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        button.tintColor = UIColor.whiteColor;
        button.layer.cornerRadius = 16.0;
        button.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
        [button setTitle:@"SB" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(YouModSponsorBlockButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        objc_setAssociatedObject(self, @selector(YouModSponsorBlockButtonTapped:), button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat bottom = CGRectGetHeight(self.bounds) - self.safeAreaInsets.bottom - 80.0;
    button.frame = CGRectMake(12.0, bottom, 32.0, 32.0);
    [self bringSubviewToFront:button];
}

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
- (void)YouModSponsorBlockButtonTapped:(UIButton *)sender {
    YTPlayerViewController *player = (YTPlayerViewController *)(self.delegate.parentViewController ?: YouModSponsorBlockCurrentPlayer);
    YouModSponsorBlockPresentSheet(player);
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
    YTMainAppVideoPlayerOverlayViewController *delegate = nil;
    @try {
        delegate = [(id)self valueForKey:@"_delegate"];
    } @catch (NSException *exception) {}
    YTInlinePlayerScrubUserEducationView *educationView = nil;
    @try {
        educationView = [[delegate videoPlayerOverlayView] valueForKey:@"scrubUserEducationView"];
    } @catch (NSException *exception) {}
    YouModManageHoldToSpeed(gesture, delegate, educationView);
}
%end

%hook YTShortsStartupCoordinator
- (id)evaluateResumeToShorts { return IS_ENABLED(ResumeShorts) ? nil : %orig; }
%end

%hook YTReelPausedStateCarouselView
- (void)setPausedStateCarouselVisible:(BOOL)arg1 animated:(BOOL)arg2 { IS_ENABLED(HideShortsSubscriptButton) ? %orig(NO, arg2) : %orig; }
%end

%hook YTReelWatchPlaybackOverlayView
- (void)setReelLikeButton:(id)arg1 { if (!IS_ENABLED(HideShortsLikeButton)) %orig; }
- (void)setReelDislikeButton:(id)arg1 { if (!IS_ENABLED(HideShortsDisLikeButton)) %orig; }
- (void)setViewCommentButton:(id)arg1 { if (!IS_ENABLED(HideShortsCommentButton)) %orig; }
- (void)setRemixButton:(id)arg1 { if (!IS_ENABLED(HideShortsRemixButton)) %orig; }
- (void)setShareButton:(id)arg1 { if (!IS_ENABLED(HideShortsShareButton)) %orig; }
- (void)setNativePivotButton:(id)arg1 { if (!IS_ENABLED(HideShortsAvatar)) %orig; }
- (void)setPivotButtonElementRenderer:(id)arg1 { if (!IS_ENABLED(HideShortsAvatar)) %orig; }
%end

%hook YTReelHeaderView
- (void)setTitleLabelVisible:(BOOL)arg1 animated:(BOOL)arg2 { IS_ENABLED(HideShortsLogo) ? %orig(NO, arg2) : %orig; }
%end

%hook YTReelTransparentStackView
- (void)layoutSubviews {
    %orig;
    for (UIView *button in ((UIView *)self).subviews) {
        id renderer = nil;
        @try {
            renderer = [button valueForKey:@"buttonRenderer"];
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
    id playerViewDelegate = nil;
    @try {
        playerViewDelegate = [(id)self valueForKey:@"playerViewDelegate"];
    } @catch (NSException *exception) {}
    id parent = nil;
    @try {
        parent = [playerViewDelegate valueForKey:@"parentViewController"];
    } @catch (NSException *exception) {}
    if (!IS_ENABLED(PinchToFullscreenShorts) || ![parent isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) return;

    UIView *contentView = [(UIViewController *)parent view];
    UIView *playbackOverlay = nil;
    @try {
        playbackOverlay = [contentView valueForKey:@"playbackOverlay"];
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
    UIView *playbackOverlay = nil;
    @try {
        playbackOverlay = [(id)self valueForKey:@"playbackOverlay"];
    } @catch (NSException *exception) {}
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
        id supernodes = [node valueForKey:@"supernodes"];
        if ([supernodes respondsToSelector:@selector(allObjects)])
            return [supernodes allObjects];
    } @catch (NSException *exception) {}
    return @[];
}

static UIViewController *YouModClosestViewControllerForNode(id node) {
    if ([node respondsToSelector:@selector(closestViewController)])
        return [node closestViewController];
    @try {
        return [node valueForKey:@"closestViewController"];
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
    NSString *identifier = nil;
    @try {
        identifier = [self valueForKey:@"_accessibilityIdentifier"] ?: [self valueForKey:@"accessibilityIdentifier"];
    } @catch (NSException *exception) {}

    if (IS_ENABLED(CommentManager) && [identifier isEqualToString:@"id.comment.content.label"] && [self isKindOfClass:NSClassFromString(@"ASTextNode")]) {
        NSString *comment = nil;
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
    BOOL loaded = NO;
    @try {
        loaded = [[(id)self valueForKey:@"_didLoadImage"] boolValue];
    } @catch (NSException *exception) {}
    if (IS_ENABLED(PostManager) && loaded) {
        NSURL *URL = nil;
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
    id nodeForLayer = nil;
    @try {
        nodeForLayer = [[containerNode valueForKey:@"yogaChildren"] firstObject];
    } @catch (NSException *exception) {}
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
    NSString *identifier = nil;
    @try {
        identifier = [action valueForKey:@"_accessibilityIdentifier"];
    } @catch (NSException *exception) {}
    NSDictionary *actionsToRemove = @{
        @"7": @(IS_ENABLED(RemoveDownloadMenu)),
        @"1": @(IS_ENABLED(RemoveWatchLaterMenu)),
        @"3": @(IS_ENABLED(RemoveSaveToPlaylistMenu)),
        @"5": @(IS_ENABLED(RemoveShareMenu)),
        @"12": @(IS_ENABLED(RemoveNotInterestedMenu)),
        @"31": @(IS_ENABLED(RemoveDontRecommendMenu)),
        @"58": @(IS_ENABLED(RemoveReportMenu))
    };
    if (![actionsToRemove[identifier] boolValue])
        %orig;
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
    UIView *headerView = nil;
    @try {
        headerView = [(id)self valueForKey:@"headerView"];
    } @catch (NSException *exception) {}
    if (!headerView || [headerView viewWithTag:999]) return;

    YTQTMButton *copyInfoButton = [%c(YTQTMButton) iconButton];
    copyInfoButton.accessibilityLabel = @"Copy video info";
    copyInfoButton.tag = 999;
    if ([copyInfoButton respondsToSelector:@selector(enableNewTouchFeedback)])
        [copyInfoButton performSelector:@selector(enableNewTouchFeedback)];
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
    if (IS_ENABLED(ShortsOnlyMode) && (IS_ENABLED(HideShortsTab) || IS_ENABLED(RestoreExploreTab))) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:HideShortsTab];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:RestoreExploreTab];
    }
}
