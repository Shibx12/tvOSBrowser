#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BrowserAppearance : NSObject

+ (nullable UIBlurEffect *)chromeBlurEffect;
+ (UIColor *)chromeFallbackColor;
+ (UIColor *)chromeBorderColor;
+ (UIColor *)chromeShadowColor;
+ (UIColor *)activeTabColor;
+ (UIColor *)inactiveTabColor;
+ (UIColor *)focusedControlColor;
+ (UIColor *)controlBorderColor;
+ (UIColor *)focusedBorderColor;
+ (UIColor *)primaryTextColor;
+ (UIColor *)secondaryTextColor;
+ (UIColor *)disabledTextColor;

@end

NS_ASSUME_NONNULL_END
