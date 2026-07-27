#import "BrowserAddressInterpreter.h"

@implementation BrowserAddressInterpreter

- (NSString *)trimmedInput:(NSString *)input {
    if (input == nil) {
        return @"";
    }
    return [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (BOOL)inputLooksLikeWebAddress:(NSString *)input {
    NSString *value = [self trimmedInput:input];
    if (value.length == 0 || [value rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) {
        return NO;
    }

    NSRange schemeSeparator = [value rangeOfString:@"://"];
    if (schemeSeparator.location != NSNotFound && schemeSeparator.location > 0) {
        return YES;
    }

    NSString *hostCandidate = value;
    NSRange pathSeparator = [hostCandidate rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
    if (pathSeparator.location != NSNotFound) {
        hostCandidate = [hostCandidate substringToIndex:pathSeparator.location];
    }
    NSRange portSeparator = [hostCandidate rangeOfString:@":" options:NSBackwardsSearch];
    if (portSeparator.location != NSNotFound) {
        hostCandidate = [hostCandidate substringToIndex:portSeparator.location];
    }

    if ([hostCandidate caseInsensitiveCompare:@"localhost"] == NSOrderedSame) {
        return YES;
    }
    if ([hostCandidate containsString:@"."] && ![hostCandidate hasPrefix:@"."] && ![hostCandidate hasSuffix:@"."]) {
        return YES;
    }

    NSCharacterSet *nonNumericAddressCharacters =
        [[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet];
    return [hostCandidate rangeOfCharacterFromSet:nonNumericAddressCharacters].location == NSNotFound &&
        [hostCandidate containsString:@"."];
}

- (NSString *)normalizedURLStringForInput:(NSString *)input {
    NSString *value = [self trimmedInput:input];
    if (![self inputLooksLikeWebAddress:value]) {
        return nil;
    }
    if ([value rangeOfString:@"://"].location != NSNotFound) {
        return value;
    }
    return [@"https://" stringByAppendingString:value];
}

@end
