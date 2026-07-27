#import <UIKit/UIKit.h>

@class BrowserViewModel;
@class CompactTabBarView;

NS_ASSUME_NONNULL_BEGIN

@protocol CompactTabBarViewDelegate <NSObject>

- (void)compactTabBarView:(CompactTabBarView *)tabBarView didSelectTabAtIndex:(NSInteger)tabIndex;
- (void)compactTabBarView:(CompactTabBarView *)tabBarView didRequestCloseTabAtIndex:(NSInteger)tabIndex;

@end

@interface CompactTabBarView : UIView

@property (nonatomic, weak, nullable) id<CompactTabBarViewDelegate> delegate;
@property (nonatomic, getter=isChromeFocusEnabled) BOOL chromeFocusEnabled;

- (instancetype)initWithViewModel:(BrowserViewModel *)viewModel NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)applyViewModelUpdate;
- (nullable UIView *)preferredFocusItem;
- (BOOL)containsFocusedItem:(nullable UIView *)focusedItem;
- (BOOL)containsInteractiveControlAtPoint:(CGPoint)point;
- (BOOL)handlePrimaryActionAtPoint:(CGPoint)point;
- (BOOL)getMagnetPoint:(CGPoint *)magnetPoint
              forPoint:(CGPoint)point
       maximumDistance:(CGFloat)maximumDistance;
- (void)refreshAppearance;

@end

NS_ASSUME_NONNULL_END
