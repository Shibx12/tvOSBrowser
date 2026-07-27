#import <UIKit/UIKit.h>

#import "BrowserToolbarView.h"

@class BrowserChromeViewController;
@class BrowserViewModel;

NS_ASSUME_NONNULL_BEGIN

@protocol BrowserChromeViewControllerDelegate <NSObject>

- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
                   didTriggerAction:(BrowserChromeAction)action;
- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
                didSelectTabAtIndex:(NSInteger)tabIndex;
- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
           didRequestCloseTabAtIndex:(NSInteger)tabIndex;
- (void)browserChromeViewControllerDidRequestAddressInput:(BrowserChromeViewController *)viewController;
- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
             didSubmitAddressString:(NSString *)addressString;

@end

@interface BrowserChromeViewController : UIViewController

@property (nonatomic, weak, nullable) id<BrowserChromeViewControllerDelegate> delegate;
@property (nonatomic, readonly, getter=isChromeVisible) BOOL chromeVisible;
@property (nonatomic, readonly, getter=isFocusModeActive) BOOL focusModeActive;
@property (nonatomic, readonly, getter=isChromeAutoHidden) BOOL chromeAutoHidden;

- (instancetype)initWithViewModel:(BrowserViewModel *)viewModel NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)updateWithTitle:(nullable NSString *)title
              URLString:(nullable NSString *)URLString
                loading:(BOOL)loading
              canGoBack:(BOOL)canGoBack
           canGoForward:(BOOL)canGoForward;
- (void)setChromeVisible:(BOOL)visible;
- (void)setChromeAutoHidden:(BOOL)autoHidden animated:(BOOL)animated;
- (void)setFocusModeActive:(BOOL)focusModeActive;
- (nullable UIView *)preferredFocusItem;
- (BOOL)shouldExitChromeForDownPress;
- (BOOL)containsInteractiveControlAtPoint:(CGPoint)point;
- (BOOL)handlePrimaryActionAtPoint:(CGPoint)point;
- (BOOL)getMagnetPoint:(CGPoint *)magnetPoint
              forPoint:(CGPoint)point
       maximumDistance:(CGFloat)maximumDistance;

@end

NS_ASSUME_NONNULL_END
