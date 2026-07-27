#import "BrowserAddressBarView.h"

#import "BrowserAnimationConstants.h"
#import "BrowserAppearance.h"

@interface BrowserAddressTextField : UITextField

@property (nonatomic, copy, nullable) void (^focusChangeHandler)(BOOL focused);

@end

@implementation BrowserAddressTextField

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context
       withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    if (self.focusChangeHandler != nil) {
        [coordinator addCoordinatedAnimations:^{
            self.focusChangeHandler(self.isFocused);
        } completion:nil];
    }
}

@end

@interface BrowserAddressBarView () <UITextFieldDelegate>

@property (nonatomic) UIView *backgroundPanel;
@property (nonatomic) UIImageView *securityImageView;
@property (nonatomic) BrowserAddressTextField *textField;
@property (nonatomic) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy) NSString *pageTitle;
@property (nonatomic, copy) NSString *URLString;
@property (nonatomic, getter=isAddressFocused) BOOL addressFocused;

@end

@implementation BrowserAddressBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _pageTitle = @"";
        _URLString = @"";
        self.backgroundColor = UIColor.clearColor;

        _backgroundPanel = [UIView new];
        _backgroundPanel.translatesAutoresizingMaskIntoConstraints = NO;
        _backgroundPanel.layer.cornerRadius = 18.0;
        _backgroundPanel.layer.borderWidth = 1.0;
        _backgroundPanel.clipsToBounds = YES;
        [self addSubview:_backgroundPanel];

        _securityImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"globe"]];
        _securityImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _securityImageView.contentMode = UIViewContentModeScaleAspectFit;
        [_backgroundPanel addSubview:_securityImageView];

        _textField = [BrowserAddressTextField new];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.delegate = self;
        _textField.borderStyle = UITextBorderStyleNone;
        _textField.backgroundColor = UIColor.clearColor;
        _textField.font = [UIFont systemFontOfSize:25.0 weight:UIFontWeightMedium];
        _textField.textAlignment = NSTextAlignmentCenter;
        _textField.keyboardType = UIKeyboardTypeURL;
        _textField.returnKeyType = UIReturnKeyGo;
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.placeholder = @"Search or enter website";
        [_backgroundPanel addSubview:_textField];

        __weak typeof(self) weakSelf = self;
        _textField.focusChangeHandler = ^(BOOL focused) {
            weakSelf.addressFocused = focused;
            [weakSelf refreshAppearance];
        };

        _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        _loadingIndicator.hidesWhenStopped = YES;
        [_backgroundPanel addSubview:_loadingIndicator];

        [NSLayoutConstraint activateConstraints:@[
            [_backgroundPanel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_backgroundPanel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_backgroundPanel.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_backgroundPanel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [_securityImageView.leadingAnchor constraintEqualToAnchor:_backgroundPanel.leadingAnchor constant:18.0],
            [_securityImageView.centerYAnchor constraintEqualToAnchor:_backgroundPanel.centerYAnchor],
            [_securityImageView.widthAnchor constraintEqualToConstant:28.0],
            [_securityImageView.heightAnchor constraintEqualToConstant:28.0],

            [_textField.leadingAnchor constraintEqualToAnchor:_securityImageView.trailingAnchor constant:12.0],
            [_textField.trailingAnchor constraintEqualToAnchor:_loadingIndicator.leadingAnchor constant:-12.0],
            [_textField.topAnchor constraintEqualToAnchor:_backgroundPanel.topAnchor constant:5.0],
            [_textField.bottomAnchor constraintEqualToAnchor:_backgroundPanel.bottomAnchor constant:-5.0],

            [_loadingIndicator.trailingAnchor constraintEqualToAnchor:_backgroundPanel.trailingAnchor constant:-18.0],
            [_loadingIndicator.centerYAnchor constraintEqualToAnchor:_backgroundPanel.centerYAnchor],
            [_loadingIndicator.widthAnchor constraintEqualToConstant:28.0],
            [_loadingIndicator.heightAnchor constraintEqualToConstant:28.0],
        ]];
        [self refreshAppearance];
    }
    return self;
}

- (void)setChromeFocusEnabled:(BOOL)chromeFocusEnabled {
    _chromeFocusEnabled = chromeFocusEnabled;
    self.textField.enabled = chromeFocusEnabled;
    [self refreshAppearance];
}

- (void)updateWithTitle:(NSString *)title URLString:(NSString *)URLString loading:(BOOL)loading {
    self.pageTitle = title ?: @"";
    self.URLString = URLString ?: @"";
    if (!self.textField.isEditing) {
        self.textField.text = [self displayText];
    }

    BOOL secure = [self.URLString.lowercaseString hasPrefix:@"https://"];
    NSString *symbolName = secure ? @"lock.fill" : @"globe";
    self.securityImageView.image = [UIImage systemImageNamed:symbolName];
    if (loading) {
        [self.loadingIndicator startAnimating];
    } else {
        [self.loadingIndicator stopAnimating];
    }
}

- (NSString *)displayText {
    if (self.pageTitle.length > 0 && ![self.pageTitle isEqualToString:@"New Tab"]) {
        return self.pageTitle;
    }
    NSURL *URL = [NSURL URLWithString:self.URLString];
    if (URL.host.length > 0) {
        return URL.host;
    }
    return self.URLString.length > 0 ? self.URLString : @"Search or enter website";
}

- (UIView *)preferredFocusItem {
    return self.textField;
}

- (BOOL)containsFocusedItem:(UIView *)focusedItem {
    return focusedItem == self.textField || [focusedItem isDescendantOfView:self];
}

- (void)refreshAppearance {
    BOOL focused = self.addressFocused;
    self.backgroundPanel.backgroundColor = focused
        ? [BrowserAppearance focusedControlColor]
        : [UIColor colorWithWhite:0.0 alpha:UIAccessibilityIsReduceTransparencyEnabled() ? 0.30 : 0.18];
    self.backgroundPanel.layer.borderColor = focused
        ? [BrowserAppearance focusedBorderColor].CGColor
        : [BrowserAppearance controlBorderColor].CGColor;
    self.backgroundPanel.layer.borderWidth = focused ? 2.0 : 1.0;
    self.textField.textColor = self.chromeFocusEnabled
        ? [BrowserAppearance primaryTextColor]
        : [BrowserAppearance secondaryTextColor];
    self.textField.tintColor = [BrowserAppearance primaryTextColor];
    self.securityImageView.tintColor = focused
        ? [BrowserAppearance primaryTextColor]
        : [BrowserAppearance secondaryTextColor];
    self.loadingIndicator.color = [BrowserAppearance primaryTextColor];
    self.transform = focused
        ? CGAffineTransformMakeScale(BrowserChromeFocusedScale(), BrowserChromeFocusedScale())
        : CGAffineTransformIdentity;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    textField.textAlignment = NSTextAlignmentLeft;
    textField.text = self.URLString;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    textField.textAlignment = NSTextAlignmentCenter;
    textField.text = [self displayText];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString *submittedString = textField.text ?: @"";
    [textField resignFirstResponder];
    if (submittedString.length > 0) {
        [self.delegate browserAddressBarView:self didSubmitAddressString:submittedString];
    }
    return YES;
}

@end
