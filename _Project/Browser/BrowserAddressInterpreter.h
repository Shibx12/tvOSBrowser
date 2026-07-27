#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BrowserAddressInterpreter : NSObject

- (NSString *)trimmedInput:(nullable NSString *)input;
- (BOOL)inputLooksLikeWebAddress:(nullable NSString *)input;
- (nullable NSString *)normalizedURLStringForInput:(nullable NSString *)input;

@end

NS_ASSUME_NONNULL_END
