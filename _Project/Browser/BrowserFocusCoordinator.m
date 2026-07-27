#import "BrowserFocusCoordinator.h"

@interface BrowserFocusCoordinator ()

@property (nonatomic, weak) UIView *lastFocusedItem;
@property (nonatomic, readwrite) BrowserFocusRegion currentRegion;

@end

@implementation BrowserFocusCoordinator

- (void)recordFocusedItem:(UIView *)focusedItem region:(BrowserFocusRegion)region {
    self.lastFocusedItem = focusedItem;
    self.currentRegion = region;
}

- (UIView *)preferredFocusItemWithFallback:(UIView *)fallback {
    if (self.lastFocusedItem.window != nil && self.lastFocusedItem.canBecomeFocused) {
        return self.lastFocusedItem;
    }
    return fallback;
}

- (BOOL)shouldExitChromeForDownPress {
    return self.currentRegion == BrowserFocusRegionTabs ||
        self.currentRegion == BrowserFocusRegionAddress ||
        self.currentRegion == BrowserFocusRegionToolbar;
}

- (void)reset {
    self.lastFocusedItem = nil;
    self.currentRegion = BrowserFocusRegionNone;
}

@end
