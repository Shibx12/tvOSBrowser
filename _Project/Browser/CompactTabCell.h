#import <UIKit/UIKit.h>

@class BrowserTabViewModel;
@class CompactTabCell;

NS_ASSUME_NONNULL_BEGIN

@protocol CompactTabCellDelegate <NSObject>

- (void)compactTabCellDidRequestClose:(CompactTabCell *)cell;

@end

@interface CompactTabCell : UICollectionViewCell

@property (nonatomic, weak, nullable) id<CompactTabCellDelegate> delegate;
@property (nonatomic, copy, readonly) NSString *tabIdentifier;
@property (nonatomic, getter=isChromeFocusEnabled) BOOL chromeFocusEnabled;

- (void)configureWithTab:(BrowserTabViewModel *)tab
                selected:(BOOL)selected
                 loading:(BOOL)loading;
- (BOOL)containsCloseButtonAtPoint:(CGPoint)point;
- (BOOL)handleCloseButtonAtPoint:(CGPoint)point;
- (CGPoint)closeButtonCenterInView:(UIView *)view;
- (void)refreshAppearance;

@end

NS_ASSUME_NONNULL_END
