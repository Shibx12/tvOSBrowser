#import "BrowserAnimationConstants.h"

NSTimeInterval BrowserChromeFocusAnimationDuration(void) {
    return UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.16;
}

CGFloat BrowserChromeFocusedScale(void) {
    return UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 1.04;
}

UIViewAnimationOptions BrowserChromeFocusAnimationOptions(void) {
    return UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction |
        UIViewAnimationOptionCurveEaseOut;
}
