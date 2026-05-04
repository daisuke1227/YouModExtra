// Perferences and headers
// For Tweak.x
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTRightNavigationButtons.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTPlayerBarController.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTWatchController.h>
#import <YouTubeHeader/YTIMenuConditionalServiceItemRenderer.h>
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTIBrowseRequest.h>
#import <YouTubeHeader/YTPivotBarItemView.h>
#import <YouTubeHeader/YTActionSheetAction.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTVideoQualitySwitchOriginalController.h>
#import <YouTubeHeader/YTVideoQualitySwitchRedesignedController.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <YouTubeHeader/YTIShowFullscreenInterstitialCommand.h>
#import <YouTubeHeader/YTISectionListRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIWatchNextResponse.h>
#import <YouTubeHeader/YTPlayerOverlay.h>
#import <YouTubeHeader/YTPlayerOverlayProvider.h>
#import <YouTubeHeader/YTReelModel.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTVarispeedSwitchController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerImpl.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>
#import <YouTubeHeader/YTMultiSizeViewController.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTSingleVideoTime.h>
#import <YouTubeHeader/YTSingleVideoController.h>
#import <YouTubeHeader/YTPlayerView.h>
#import <YouTubeHeader/YTLabel.h>
#import <YouTubeHeader/YTCommonColorPalette.h>
#import <YouTubeHeader/MLFormat.h>
#import <YouTubeHeader/MLQuickMenuVideoQualitySettingFormatConstraint.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// For Settings.x
#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSearchableSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTToastResponderEvent.h>
#import <YouTubeHeader/YTUIUtils.h>

#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:k]
#define INTFORVAL(v) [[NSUserDefaults standardUserDefaults] integerForKey:v]
// Cache
#define AutoClearCache @"YouModAutoClearCache"
// Appearance
#define OLEDTheme @"YouModEnablesOLEDTheme"
#define OLEDKeyboard @"YouModEnablesOLEDKeyboard"
// Navigation bar
#define HideYTLogo @"YouModHideYTLogo"
#define YTPremiumLogo @"YouModYTPremiumLogo"
#define HideNoti @"YouModHideNotificationButton"
#define HideSearch @"YouModHideSearchButton"
#define HideVoiceSearch @"YouModHideVoiceSearchButton"
#define HideCastButtonNav @"YouModHideCastButtonNavigationBar"
// Feed
#define HideSubbar @"YouModHideSubbar"
#define HideGenMusicShelf @"YouModHideGenMusicShelf"
#define HideFeedPost @"YouModHideFeedPost"
#define HideShortsShelf @"YouModHideShortsShelf"
#define HideSearchHis @"YouModHideSearchHistoryAndSuggestions"
#define HideSubButton @"YouModHideSubscribeButton"
#define HideShoppingButton @"YouModHideShoppingButton"
#define HideMemberButton @"YouModHideMemberButton"
// Player
#define HideAutoPlayToggle @"YouModHideAutoPlayToggle"
#define HideCaptionsButton @"YouModHideCaptionsButton"
#define HideCastButtonPlayer @"YouModHideCastButtonPlayer"
#define HidePrevButton @"YouModHidePrevButton"
#define HideNextButton @"YouModHideNextButton"
#define ReplacePrevNextButtons @"YouModReplacePrevNextButtons"
#define RemoveDarkOverlay @"YouModRemoveDarkOverlay"
#define RemoveAmbiant @"YouModRemoveAmbiantColors"
#define HideEndScreenCards @"YouModHideEndScreenCards"
#define HideSuggestedVideo @"YouModHideSuggestedVideoOnFinish"
#define HidePaidPromoOverlay @"YouModHidePaidPromoOverlay"
#define HideWaterMark @"YouModHideWaterMark"
#define GestureControls @"YouModEnableGesturesControls"
#define GestureActivationArea @"YouModGestureActivationArea"
#define LeftSideGesture @"YouModLeftSideGesture"
#define RightSideGesture @"YouModRightSideGesture"
#define GestureHUD @"YouModGestureHUD"
#define DisablesDoubleTap @"YouModDisablesDoubleTap"
#define DisablesLongHold @"YouModDisablesLongHold"
#define AutoExitFullScreen @"YouModAutoExitFullScreen"
#define DisablesCaptions @"YouModAutoDisablesCaptions"
#define DisablesShowRemaining @"YouModDisablesShowRemainingTime"
#define AlwaysShowRemaining @"YouModAlwaysShowRemainingTime"
#define ShowExtraTimeRemaining @"YouModShowExtraTimeRemaining"
#define HideFullAction @"YouModHideFullScreenAction"
#define HideFullvidTitle @"YouModHideFullscreenVideoTitle"
#define StopAutoplayVideo @"YouModStopAutoplayVideo"
#define HideContentWarning @"YouModHideContentWarning"
#define AutoFullScreen @"YouModAutoFullScreen"
#define PortFull @"YouModPortraitFullscreen"
#define OldQualityPicker @"YouModUseOldQualityPicker"
#define ExtraSpeed @"YouModAddExtraSpeed"
#define DisableHints @"YouModDisableHints"
#define ForceMiniPlayer @"YouModForceMiniPlayer"
#define AlwaysShowSeekbar @"YouModAlwaysShowSeekbar"
#define PersistentProgressBar @"YouModPersistentProgressBar"
#define StockVolumeHUD @"YouModStockVolumeHUD"
#define RedProgressBar @"YouModRedProgressBar"
#define PauseOnOverlay @"YouModPauseOnOverlay"
#define NoTwoFingerSnapToChapter @"YouModNoTwoFingerSnapToChapter"
#define NoFreeZoom @"YouModNoFreeZoom"
#define VideoEndTime @"YouModVideoEndTime"
#define Use24HourTime @"YouModUse24HourTime"
#define CopyWithTimestamp @"YouModCopyWithTimestamp"
#define HoldToSpeedIndex @"YouModHoldToSpeedIndex"
#define DefaultPlaybackRateIndex @"YouModDefaultPlaybackRateIndex"
#define AutoQualityWiFiIndex @"YouModAutoQualityWiFiIndex"
#define AutoQualityCellularIndex @"YouModAutoQualityCellularIndex"
#define HideLikeButton @"YouModHideLikeButton"
#define HideDisLikeButton @"YouModHideDisLikeButton"
#define HideShareButton @"YouModHideShareButton"
#define HideDownloadButton @"YouModHideDownloadButton"
#define HideClipButton @"YouModHideClipButton"
#define HideRemixButton @"YouModHideRemixButton"
#define HideSaveButton @"YouModHideSaveButton"

#define DownloadManager @"YouModDownloadManager"
#define DownloadSaveToPhotos @"YouModDownloadSaveToPhotos"
#define DownloadPreferDRCAudio @"YouModDownloadPreferDRCAudio"

#define HideShortsLikeButton @"YouModHideShortsLikeButton"
#define HideShortsDisLikeButton @"YouModHideShortsDisLikeButton"
#define HideShortsCommentButton @"YouModHideShortsCommentButton"
#define HideShortsShareButton @"YouModHideShortsShareButton"
#define HideShortsRemixButton @"YouModHideShortsRemixButton"
#define HideShortsMetaButton @"YouModHideShortsMetaButton"
#define HideShortsProducts @"YouModHideShortsProducts"
#define HideShortsRecbar @"YouModHideShortsRecbar"
#define HideShortsCommit @"YouModHideShortsCommit"
#define HideShortsSubscriptButton @"YouModHideShortsSubscriptButton"
#define HideShortsLiveButton @"YouModHideShortsLiveButton"
#define HideShortsLensButton @"YouModHideShortsLensButton"
#define HideShortsTrendsButton @"YouModHideShortsTrendsButton"
#define HideShortsToVideo @"YouModHideShortsToVideo"
#define EnablesShortsQuality @"YouModEnablesShortsQuality"
#define ShowShortsSeekbar @"YouModShowShortsSeekbar"
#define ShortsOnlyMode @"YouModShortsOnlyMode"
#define AutoSkipShorts @"YouModAutoSkipShorts"
#define ShortsToRegular @"YouModShortsToRegular"
#define ResumeShorts @"YouModResumeShorts"
#define PinchToFullscreenShorts @"YouModPinchToFullscreenShorts"
#define HideShortsLogo @"YouModHideShortsLogo"
#define HideShortsSearchButton @"YouModHideShortsSearchButton"
#define HideShortsCameraButton @"YouModHideShortsCameraButton"
#define HideShortsMoreButton @"YouModHideShortsMoreButton"
#define HideShortsAvatar @"YouModHideShortsAvatar"
#define HideShortsChannelName @"YouModHideShortsChannelName"
#define HideShortsDescription @"YouModHideShortsDescription"
#define HideShortsAudioTrack @"YouModHideShortsAudioTrack"
#define HideShortsPromoCards @"YouModHideShortsPromoCards"
#define HideShortsThanks @"YouModHideShortsThanks"
#define HideShortsSource @"YouModHideShortsSource"

#define DefaultTab @"YouModDefaultStartupTab"
#define HideTabIndi @"YouModHideTabIndicators"
#define HideTabLabels @"YouModHideTabLabels"
#define HideHomeTab @"YouModHideHomeTab"
#define HideShortsTab @"YouModHideShortsTab"
#define HideCreateButton @"YouModHideCreateButton"
#define HideSubscriptTab @"YouModHideSubscriptionsTab"
// #define HideLibraryTab @"YouModHideLibraryTab"

#define BackgroundPlayback @"YouModEnablesBackgroundPlayback"
#define DisablesShortsPiP @"YouModTrytoDisablesShortsPiP"
#define BlockUpgradeDialogs @"YouModBlockUpgradeDialogs"
#define HideAreYouThereDialog @"YouModHideAreYouThereDialog"
#define FixesSlowMiniPlayer @"YouModFixesSlowMiniPlayer"
#define DisablesNewMiniPlayer @"YouModDisablesNewMiniPlayer"
#define DisablesSnackBar @"YouModDisablesSnackBar"
#define HideStartupAni @"YouModHideStartupAnimations"
#define HidePlayInNextQueue @"YouModHidePlayInNextQueue"
#define HideLikeDislikeVotes @"YouModHideLikeDislikeVotes"
#define NativeShare @"YouModNativeShare"
#define CopyVideoInfoPanel @"YouModCopyVideoInfoPanel"
#define PostManager @"YouModPostManager"
#define SaveProfilePhoto @"YouModSaveProfilePhoto"
#define CommentManager @"YouModCommentManager"
#define FixAlbums @"YouModFixAlbums"
#define RemoveDownloadMenu @"YouModRemoveDownloadMenu"
#define RemoveWatchLaterMenu @"YouModRemoveWatchLaterMenu"
#define RemoveSaveToPlaylistMenu @"YouModRemoveSaveToPlaylistMenu"
#define RemoveShareMenu @"YouModRemoveShareMenu"
#define RemoveNotInterestedMenu @"YouModRemoveNotInterestedMenu"
#define RemoveDontRecommendMenu @"YouModRemoveDontRecommendMenu"
#define RemoveReportMenu @"YouModRemoveReportMenu"
#define HideContinueWatching @"YouModHideContinueWatching"
#define HideRelatedWatchNexts @"YouModHideRelatedWatchNexts"
#define StickSortComments @"YouModStickSortComments"
#define HideSortComments @"YouModHideSortComments"
#define PlaylistOldMinibar @"YouModPlaylistOldMinibar"
#define DisableRTL @"YouModDisableRTL"
#define SleepTimerEnabled @"YouModSleepTimerEnabled"

#define YT_BUNDLE_ID @"com.google.ios.youtube"
#define YT_NAME @"YouTube"

// Gesture Section Enum
typedef NS_ENUM(NSUInteger, GestureSection) {
    GestureSectionTop,
    GestureSectionBottom,
    GestureSectionInvalid
};

@interface YTITopbarLogoRenderer : NSObject
@property(readonly, nonatomic) YTIIcon *iconImage;
@end

@interface YTRightNavigationButtons (YouMod)
@property (nonatomic, strong) YTQTMButton *notificationButton;
@property (nonatomic, strong) YTQTMButton *searchButton;
@end

@interface YTMainAppVideoPlayerOverlayView (YouMod)
@property (nonatomic, strong) YTQTMButton *playbackRouteButton;
@end

@interface YTNavigationBarTitleView : UIView
@end

@interface YTChipCloudCell : UICollectionViewCell
@end

@interface YTSearchViewController : UIViewController
@end

@interface YTPlayabilityResolutionUserActionUIController : NSObject
- (void)confirmAlertDidPressConfirm;
@end

@interface YTPlayabilityResolutionUserActionUIControllerImpl : NSObject
- (void)confirmAlertDidPressConfirm;
@end

@interface YTPivotBarViewController : UIViewController
@property (nonatomic, weak, readwrite) UIViewController *parentViewController;
- (void)selectItemWithPivotIdentifier:(id)pivotIndentifier;
@end

@interface YTAppViewController : UIViewController
- (void)hidePivotBar;
- (void)showPivotBar;
@end

@interface YTPlayerViewController (YouMod) <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UIPanGestureRecognizer *YouModPanGesture;
@property (nonatomic, retain) UILabel *YouModGestureHUD;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (void)YouModAutoFullscreen;
- (void)YouModTurnOffCaptions;
- (void)setActiveCaptionTrack:(id)arg1 source:(long long)arg2;
- (void)setPlaybackRate:(float)rate;
@end

@interface SSOConfiguration : NSObject
@end

@interface YTVideoQualitySwitchOriginalController (YouMod)
@property (retain, nonatomic) YTVideoQualitySwitchRedesignedController *redesignedController;
@end

@interface UIView (Private)
@property (nonatomic, assign, readonly) BOOL _mapkit_isDarkModeEnabled;
- (UIViewController *)_viewControllerForAncestor;
@end

@interface UIKeyboard : UIView // Regular keyboard
+ (instancetype)activeKeyboard;
@end

@interface UIPredictionViewController : UIViewController // Keyboard with enabled predictions panel
@end

@interface UIKeyboardDockView : UIView // Dock under keyboard for notched devices
@end

@interface UIKBVisualEffectView : UIVisualEffectView
@property (nonatomic, copy, readwrite) NSArray *backgroundEffects;
@end

@interface YTAppDelegate : UIResponder
- (void)YouModAutoClearCache;
@end

// Custom perferences logics
@interface YouModPrefsManager : NSObject <UIDocumentPickerDelegate>
+ (instancetype)sharedManager;
- (void)exportYouModSettingsFromVC:(UIViewController *)vc;
- (void)importYouModSettingsFromVC:(UIViewController *)vc;
- (void)restoreYouModDefaults;
@end

// Player Gestures - @bhackel (YTLitePlus)
@interface YTFineScrubberFilmstripView : UIView
@end

@interface YTFineScrubberFilmstripCollectionView : UICollectionView
@end

@interface YTWatchFullscreenViewController : YTMultiSizeViewController
@end

@interface YTPlayerBarController (YouMod)
- (void)didScrub:(UIPanGestureRecognizer *)gestureRecognizer;
- (void)startScrubbing;
- (void)didScrubToPoint:(CGPoint)point;
- (void)endScrubbingForSeekSource:(int)seekSource;
@end

@interface YTMainAppVideoPlayerOverlayViewController (YouMod)
@property (nonatomic, strong, readwrite) YTPlayerBarController *playerBarController;
- (NSString *)videoID;
- (CGFloat)mediaTime;
@end

@interface YTInlinePlayerBarContainerView (YouMod)
@property UIPanGestureRecognizer *scrubGestureRecognizer;
@property (nonatomic, strong, readwrite) YTFineScrubberFilmstripView *fineScrubberFilmstrip;
@property (nonatomic, strong, readwrite) NSString *endTimeString;
- (CGFloat)scrubXForScrubRange:(CGFloat)scrubRange;
@end

@interface YTSingleVideoController (YouMod)
@property (nonatomic, assign, readonly) CGFloat totalMediaTime;
@end

@interface YTReelContentView : UIView
@end

@interface YTImageZoomNode : NSObject
@end

@interface YTEngagementPanelView : UIView
@end
