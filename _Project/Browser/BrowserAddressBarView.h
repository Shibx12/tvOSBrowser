#import <UIKit/UIKit.h>

@class BrowserAddressBarView;

NS_ASSUME_NONNULL_BEGIN

@protocol BrowserAddressBarViewDelegate <NSObject>

- (void)browserAddressBarView:(BrowserAddressBarView *)addressBarView
       didSubmitAddressString:(NSString *)addressString;

@end

@interface BrowserAddressBarView : UIView

@property (nonatomic, weak, nullable) id<BrowserAddressBarViewDelegate> delegate;
@property (nonatomic, getter=isChromeFocusEnabled) BOOL chromeFocusEnabled;

- (void)updateWithTitle:(nullable NSString *)title
              URLString:(nullable NSString *)URLString
                loading:(BOOL)loading;
- (nullable UIView *)preferredFocusItem;
- (BOOL)containsFocusedItem:(nullable UIView *)focusedItem;
- (void)refreshAppearance;

@end

NS_ASSUME_NONNULL_END
