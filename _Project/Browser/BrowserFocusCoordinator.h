#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BrowserFocusRegion) {
    BrowserFocusRegionNone = 0,
    BrowserFocusRegionTabs,
    BrowserFocusRegionAddress,
    BrowserFocusRegionToolbar
};

@interface BrowserFocusCoordinator : NSObject

@property (nonatomic, readonly) BrowserFocusRegion currentRegion;

- (void)recordFocusedItem:(UIView *)focusedItem region:(BrowserFocusRegion)region;
- (nullable UIView *)preferredFocusItemWithFallback:(nullable UIView *)fallback;
- (BOOL)shouldExitChromeForDownPress;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
