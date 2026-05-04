#import "Headers.h"

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    NSMutableIndexSet *indicesToRemove = [NSMutableIndexSet indexSet];
    // Loop through every item in the bar
    for (NSUInteger i = 0; i < items.count; i++) {
        YTIPivotBarSupportedRenderers *item = items[i];
        NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier];
        NSString *pID2 = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
        if ([pID isEqualToString:@"FEwhat_to_watch"] && IS_ENABLED(HideHomeTab)) {
             [indicesToRemove addIndex:i];
        }
        if ([pID isEqualToString:@"FEshorts"] && IS_ENABLED(HideShortsTab)) {
            [indicesToRemove addIndex:i];
        }
        if ([pID2 isEqualToString:@"FEuploads"] && IS_ENABLED(HideCreateButton)) {
            [indicesToRemove addIndex:i];
        }
        if ([pID isEqualToString:@"FEsubscriptions"] && IS_ENABLED(HideSubscriptTab)) {
            [indicesToRemove addIndex:i];
        }
        /*
        if ([pID isEqualToString:@"FElibrary"] && IS_ENABLED(HideLibraryTab)) {
            [indicesToRemove addIndex:i];
        }
        if ([pID isEqualToString:@"FEshorts"] && IS_ENABLED(RestoreExploreTab)) {
            [indicesToRemove addIndex:i];
        }
        */
    }
    // Remove them all at once so the layout doesn't break
    [items removeObjectsAtIndexes:indicesToRemove];
    /* Disabled - YouTube fully removed this tab from server-side
    NSUInteger exploreIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:[%c(YTIBrowseRequest) browseIDForExploreTab]];
    }];
    if (exploreIndex == NSNotFound && (IS_ENABLED(RestoreExploreTab) || IS_ENABLED(AddExploreTab))) {
        YTIPivotBarSupportedRenderers *exploreTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForExploreTab] title:@"Explore" iconType:292];
        NSUInteger insertIndex = MIN((NSUInteger)1, items.count);
        [items insertObject:exploreTab atIndex:insertIndex];
    }
    */
    %orig(renderer);
}
%end

// Hide Tab Bar Indicators
%hook YTPivotBarIndicatorView
- (void)setFillColor:(id)arg1 { IS_ENABLED(HideTabIndi) ? %orig([UIColor clearColor]) : %orig; }
- (void)setBorderColor:(id)arg1  { IS_ENABLED(HideTabIndi) ? %orig([UIColor clearColor]) : %orig; }
%end

// Hide Tab Labels
%hook YTPivotBarItemView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    %orig;
    if (IS_ENABLED(HideTabLabels)) {
        [self.navigationButton setTitle:@"" forState:UIControlStateNormal];
        [self.navigationButton setSizeWithPaddingAndInsets:NO];
    }
}
%end

BOOL isTabSelected = NO;
%hook YTPivotBarViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (IS_ENABLED(ShortsOnlyMode)) {
        [self selectItemWithPivotIdentifier:@"FEshorts"];
        if ([self.parentViewController respondsToSelector:@selector(hidePivotBar)])
            [self.parentViewController performSelector:@selector(hidePivotBar)];
        return;
    }
    if (!isTabSelected) {
        NSArray *pivotIdentifiers = @[@"FEwhat_to_watch", @"FEshorts", @"FEsubscriptions", @"FElibrary"];
        [self selectItemWithPivotIdentifier:pivotIdentifiers[INTFORVAL(DefaultTab)]]; // Set int here
        isTabSelected = YES;
    }
}
%end
