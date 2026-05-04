#import "Headers.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h> // For import

#define Prefix @"YouMod"

static NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:Prefix ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), Prefix]];
    });
    return bundle;
}

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

@implementation YouModPrefsManager

+ (instancetype)sharedManager {
    static YouModPrefsManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

// Import
- (void)importYouModSettingsFromVC:(UIViewController *)vc {
    NSArray<UTType *> *types = @[UTTypePropertyList, UTTypeData];

    // Modern constructor for iOS 14+
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;

    // Ensure it looks right on iPad
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = vc.view;
        picker.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width/2, vc.view.bounds.size.height/2, 0, 0);
        picker.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *selectedFileURL = urls.firstObject;
    if (!selectedFileURL) return;

    // Check if this is a SponsorBlock ID import
    if (objc_getAssociatedObject(controller, @selector(importSponsorBlockIDFromVC:))) {
        NSDictionary *importedData = [NSDictionary dictionaryWithContentsOfURL:selectedFileURL];
        NSString *importedID = importedData[@"SponsorBlockUserID"];
        if (!importedID.length) {
            YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            alertView.title = LOC(@"ERROR");
            alertView.subtitle = @"No SponsorBlock user ID found in the selected file.";
            [alertView show];
            return;
        }
        YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
            [[NSUserDefaults standardUserDefaults] setObject:importedID forKey:SponsorBlockUserID];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[%c(YTToastResponderEvent) eventWithMessage:@"SponsorBlock user ID restored from file" firstResponder:nil] send];
        } actionTitle:LOC(@"YES")];
        alertView.title = @"Replace user ID?";
        alertView.subtitle = @"This will replace your current SponsorBlock user ID with the one from the file. Your voting history and submissions will transfer. Make sure you trust this file.";
        [alertView show];
        return;
    }

    NSDictionary *importedData = [NSDictionary dictionaryWithContentsOfURL:selectedFileURL];
    // Vaild plist check
    if (!importedData || ![importedData isKindOfClass:[NSDictionary class]]) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_INVALID_FILE");
        [alertView show];
        return;
    }
    BOOL foundKeys = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // Remove old keys
    for (NSString *key in [defaults dictionaryRepresentation]) {
        if ([key hasPrefix:Prefix]) {
            [defaults removeObjectForKey:key];
        }
    }
    [defaults synchronize];
    // Set new key from file
    for (NSString *key in importedData) {
        if ([key hasPrefix:Prefix]) {
            [defaults setObject:importedData[key] forKey:key];
            foundKeys = YES;
        }
    }
    // Check if there's any YouMod key
    if (!foundKeys) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_NO_KEYS_IMPORT");
        [alertView show];
        return;
    }
    [defaults synchronize];
    // Success Alert with Restart
    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
        exit(0);
    } actionTitle:LOC(@"YES")];
    alertView.title = LOC(@"IMPORT_DONE");
    alertView.subtitle = LOC(@"APPLY_DESC"); // "Restart required"
    [alertView show];
}

// Export
- (void)exportYouModSettingsFromVC:(UIViewController *)vc {
    NSDictionary *allSettings = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSMutableDictionary *youModOnly = [NSMutableDictionary dictionary];
    for (NSString *key in allSettings) {
        if ([key hasPrefix:Prefix]) {
            youModOnly[key] = allSettings[key];
        }
    }
    if (youModOnly.count == 0) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_NO_KEYS_EXPORT");
        [alertView show];
        return;
    }
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"YouMod_Preferences.plist"];
    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    [youModOnly writeToURL:fileURL atomically:YES];

    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[fileURL] asCopy:YES];
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = vc.view;
    }
    [vc presentViewController:picker animated:YES completion:nil];
}

// Export SponsorBlock user ID to file
- (void)exportSponsorBlockIDFromVC:(UIViewController *)vc {
    NSString *userID = [[NSUserDefaults standardUserDefaults] stringForKey:SponsorBlockUserID];
    if (!userID.length) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = @"No user ID";
        alertView.subtitle = @"No SponsorBlock user ID has been generated yet. Open a video with SponsorBlock enabled first.";
        [alertView show];
        return;
    }

    NSDictionary *data = @{@"SponsorBlockUserID": userID, @"exportDate": [NSDate date].description};
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"YouMod_SponsorBlock_ID.plist"];
    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    [data writeToURL:fileURL atomically:YES];

    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[fileURL] asCopy:YES];
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = vc.view;
    }
    [vc presentViewController:picker animated:YES completion:nil];
}

// Copy SponsorBlock user ID to clipboard
- (void)copySponsorBlockID {
    NSString *userID = [[NSUserDefaults standardUserDefaults] stringForKey:SponsorBlockUserID];
    if (!userID.length) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = @"No user ID";
        alertView.subtitle = @"No SponsorBlock user ID has been generated yet.";
        [alertView show];
        return;
    }
    UIPasteboard.generalPasteboard.string = userID;
    [[%c(YTToastResponderEvent) eventWithMessage:@"SponsorBlock user ID copied to clipboard" firstResponder:nil] send];
}

// Import SponsorBlock user ID from file
- (void)importSponsorBlockIDFromVC:(UIViewController *)vc {
    NSArray<UTType *> *types = @[UTTypePropertyList, UTTypeData];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    objc_setAssociatedObject(picker, @selector(importSponsorBlockIDFromVC:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = vc.view;
        picker.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width/2, vc.view.bounds.size.height/2, 0, 0);
        picker.popoverPresentationController.permittedArrowDirections = 0;
    }
    [vc presentViewController:picker animated:YES completion:nil];
}

// Paste SponsorBlock user ID from clipboard
- (void)pasteSponsorBlockID {
    NSString *clipboardText = UIPasteboard.generalPasteboard.string;
    if (!clipboardText.length || clipboardText.length < 10) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = @"Invalid ID";
        alertView.subtitle = @"No valid SponsorBlock user ID found on the clipboard.";
        [alertView show];
        return;
    }
    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
        [[NSUserDefaults standardUserDefaults] setObject:clipboardText forKey:SponsorBlockUserID];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[%c(YTToastResponderEvent) eventWithMessage:@"SponsorBlock user ID restored from clipboard" firstResponder:nil] send];
    } actionTitle:LOC(@"YES")];
    alertView.title = @"Replace user ID?";
    alertView.subtitle = @"This will replace your current SponsorBlock user ID. Your voting history and submissions will transfer to the pasted ID. Make sure you trust the source.";
    [alertView show];
}

// Reset
- (void)restoreYouModDefaults {
    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in [defaults dictionaryRepresentation]) {
            if ([key hasPrefix:Prefix]) {
                [defaults removeObjectForKey:key];
            }
        }
        [defaults setBool:YES forKey:AutoClearCache];
        [defaults setBool:YES forKey:YTPremiumLogo];
        [defaults setBool:YES forKey:HideCreateButton];
        [defaults setBool:YES forKey:HideCastButtonNav];
        [defaults setBool:YES forKey:HideCastButtonPlayer];
        [defaults setBool:YES forKey:BackgroundPlayback];
        [defaults setBool:YES forKey:OldQualityPicker];
        [defaults synchronize];
        exit(0);
    } actionTitle:LOC(@"YES")];
    alertView.title = LOC(@"WARNING");
    alertView.subtitle = LOC(@"RESETDEFAULT");
    [alertView show];
}

@end
