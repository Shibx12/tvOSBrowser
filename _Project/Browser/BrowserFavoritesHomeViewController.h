#import <UIKit/UIKit.h>

@class BrowserFavoritesHomeViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol BrowserFavoritesHomeViewControllerDelegate <NSObject>

- (void)browserFavoritesHomeViewController:(BrowserFavoritesHomeViewController *)viewController
                        didSelectURLString:(NSString *)URLString;
- (void)browserFavoritesHomeViewControllerDidRequestAddFavorite:
    (BrowserFavoritesHomeViewController *)viewController;
- (void)browserFavoritesHomeViewController:(BrowserFavoritesHomeViewController *)viewController
       didRequestActionsForFavoriteAtIndex:(NSUInteger)index
                                     title:(NSString *)title
                                 URLString:(NSString *)URLString;

@end

@interface BrowserFavoritesHomeViewController : UIViewController

@property (nonatomic, weak, nullable) id<BrowserFavoritesHomeViewControllerDelegate> delegate;
@property (nonatomic, readonly) UIScrollView *scrollView;

- (void)reloadFavorites;
- (BOOL)containsInteractiveControlAtPoint:(CGPoint)point;
- (BOOL)handlePrimaryActionAtPoint:(CGPoint)point;
- (BOOL)handleLongPressAtPoint:(CGPoint)point;
- (BOOL)getMagnetPoint:(CGPoint *)magnetPoint
              forPoint:(CGPoint)point
       maximumDistance:(CGFloat)maximumDistance;
- (void)updatePointerHoverAtPoint:(CGPoint)point;
- (void)clearPointerHover;

@end

NS_ASSUME_NONNULL_END
