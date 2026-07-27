#import "BrowserAppearance.h"

@implementation BrowserAppearance

+ (UIBlurEffect *)chromeBlurEffect {
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        return nil;
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
}

+ (UIColor *)chromeFallbackColor {
    CGFloat alpha = UIAccessibilityIsReduceTransparencyEnabled() ? 0.98 : 0.28;
    return [UIColor colorWithRed:0.055 green:0.063 blue:0.075 alpha:alpha];
}

+ (UIColor *)chromeBorderColor {
    CGFloat alpha = UIAccessibilityDarkerSystemColorsEnabled() ? 0.42 : 0.20;
    return [UIColor colorWithWhite:1.0 alpha:alpha];
}

+ (UIColor *)chromeShadowColor {
    return [UIColor colorWithWhite:0.0 alpha:0.46];
}

+ (UIColor *)activeTabColor {
    CGFloat alpha = UIAccessibilityDarkerSystemColorsEnabled() ? 0.32 : 0.22;
    return [UIColor colorWithWhite:1.0 alpha:alpha];
}

+ (UIColor *)inactiveTabColor {
    return [UIColor colorWithWhite:1.0 alpha:0.065];
}

+ (UIColor *)focusedControlColor {
    CGFloat alpha = UIAccessibilityDarkerSystemColorsEnabled() ? 0.34 : 0.24;
    return [UIColor colorWithWhite:1.0 alpha:alpha];
}

+ (UIColor *)controlBorderColor {
    CGFloat alpha = UIAccessibilityDarkerSystemColorsEnabled() ? 0.36 : 0.14;
    return [UIColor colorWithWhite:1.0 alpha:alpha];
}

+ (UIColor *)focusedBorderColor {
    return [UIColor colorWithWhite:1.0 alpha:0.84];
}

+ (UIColor *)primaryTextColor {
    return UIColor.whiteColor;
}

+ (UIColor *)secondaryTextColor {
    return [UIColor colorWithWhite:1.0 alpha:UIAccessibilityDarkerSystemColorsEnabled() ? 0.78 : 0.64];
}

+ (UIColor *)disabledTextColor {
    return [UIColor colorWithWhite:1.0 alpha:0.30];
}

@end
