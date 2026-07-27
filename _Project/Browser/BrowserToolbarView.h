#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, BrowserChromeAction) {
    BrowserChromeActionBack = 0,
    BrowserChromeActionForward,
    BrowserChromeActionReload,
    BrowserChromeActionHome,
    BrowserChromeActionNewTab,
    BrowserChromeActionMenu
};

@class BrowserToolbarView;

NS_ASSUME_NONNULL_BEGIN

@protocol BrowserToolbarViewDelegate <NSObject>

- (void)browserToolbarView:(BrowserToolbarView *)toolbarView
          didTriggerAction:(BrowserChromeAction)action;

@end

@interface BrowserToolbarView : UIView

@property (nonatomic, weak, nullable) id<BrowserToolbarViewDelegate> delegate;
@property (nonatomic, getter=isChromeFocusEnabled) BOOL chromeFocusEnabled;

- (void)updateCanGoBack:(BOOL)canGoBack
           canGoForward:(BOOL)canGoForward
                loading:(BOOL)loading;
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
