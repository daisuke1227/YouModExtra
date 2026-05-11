#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <substrate.h>

__attribute__((constructor)) static void load_tweaks() {
    // Dummy substrate call to force linkage with CydiaSubstrate, allowing cyan to satisfy the dependency with ElleKit
    MSGetImageByName("/usr/lib/libSystem.B.dylib");

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *tweaksPath = [bundlePath stringByAppendingPathComponent:@"Tweaks"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:tweaksPath error:nil];
    
    if (files) {
        NSArray *sortedFiles = [files sortedArrayUsingSelector:@selector(compare:)];
        NSMutableArray *remainingFiles = [sortedFiles mutableCopy];
        
        // Priority tweaks that must be loaded first as they provide registration methods for others
        NSArray *priorityTweaks = @[@"YTVideoOverlay.dylib", @"YouGroupSettings.dylib"];
        
        for (NSString *priority in priorityTweaks) {
            if ([remainingFiles containsObject:priority]) {
                NSString *dylibPath = [tweaksPath stringByAppendingPathComponent:priority];
                void *handle = dlopen([dylibPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
                if (handle) {
                    NSLog(@"[TweakLoader] Priority loaded %@", priority);
                } else {
                    NSLog(@"[TweakLoader] Failed to priority load %@: %s", priority, dlerror());
                }
                [remainingFiles removeObject:priority];
            }
        }

        for (NSString *file in remainingFiles) {
            if ([file hasSuffix:@".dylib"]) {
                NSString *dylibPath = [tweaksPath stringByAppendingPathComponent:file];
                void *handle = dlopen([dylibPath UTF8String], RTLD_NOW | RTLD_GLOBAL);
                if (!handle) {
                    NSLog(@"[TweakLoader] Failed to load %@: %s", file, dlerror());
                } else {
                    NSLog(@"[TweakLoader] Loaded %@", file);
                }
            }
        }
    }
}
