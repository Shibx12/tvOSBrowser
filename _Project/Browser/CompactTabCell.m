#import "CompactTabCell.h"

#import "BrowserAnimationConstants.h"
#import "BrowserAppearance.h"
#import "BrowserTabViewModel.h"

@interface BrowserTabCloseButton : UIButton
@end

@implementation BrowserTabCloseButton

- (BOOL)canBecomeFocused {
    return NO;
}

@end

@interface CompactTabCell ()

@property (nonatomic) UIView *backgroundPanel;
@property (nonatomic) UIImageView *faviconView;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) BrowserTabCloseButton *closeButton;
@property (nonatomic, copy, readwrite) NSString *tabIdentifier;
@property (nonatomic, getter=isSelectedTab) BOOL selectedTab;

@end

@implementation CompactTabCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;
        _chromeFocusEnabled = YES;

        _backgroundPanel = [UIView new];
        _backgroundPanel.translatesAutoresizingMaskIntoConstraints = NO;
        _backgroundPanel.layer.cornerRadius = 16.0;
        _backgroundPanel.layer.borderWidth = 1.0;
        _backgroundPanel.clipsToBounds = YES;
        [self.contentView addSubview:_backgroundPanel];

        UIImage *faviconImage = [UIImage systemImageNamed:@"globe"];
        _faviconView = [[UIImageView alloc] initWithImage:faviconImage];
        _faviconView.translatesAutoresizingMaskIntoConstraints = NO;
        _faviconView.contentMode = UIViewContentModeScaleAspectFit;
        _faviconView.tintColor = [BrowserAppearance secondaryTextColor];
        [_backgroundPanel addSubview:_faviconView];

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _titleLabel.numberOfLines = 1;
        [_backgroundPanel addSubview:_titleLabel];

        _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        _loadingIndicator.hidesWhenStopped = YES;
        _loadingIndicator.color = [BrowserAppearance primaryTextColor];
        [_backgroundPanel addSubview:_loadingIndicator];

        _closeButton = [BrowserTabCloseButton buttonWithType:UIButtonTypeCustom];
        _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        _closeButton.accessibilityLabel = @"Close Tab";
        _closeButton.tintColor = [BrowserAppearance secondaryTextColor];
        _closeButton.layer.cornerRadius = 12.0;
        UIImageSymbolConfiguration *closeConfiguration =
            [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
        [_closeButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:closeConfiguration]
                      forState:UIControlStateNormal];
        [_closeButton addTarget:self
                         action:@selector(handleCloseButton:)
               forControlEvents:UIControlEventPrimaryActionTriggered];
        [_backgroundPanel addSubview:_closeButton];

        [NSLayoutConstraint activateConstraints:@[
            [_backgroundPanel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:4.0],
            [_backgroundPanel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4.0],
            [_backgroundPanel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4.0],
            [_backgroundPanel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4.0],

            [_faviconView.leadingAnchor constraintEqualToAnchor:_backgroundPanel.leadingAnchor constant:16.0],
            [_faviconView.centerYAnchor constraintEqualToAnchor:_backgroundPanel.centerYAnchor],
            [_faviconView.widthAnchor constraintEqualToConstant:28.0],
            [_faviconView.heightAnchor constraintEqualToConstant:28.0],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_faviconView.trailingAnchor constant:12.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_backgroundPanel.centerYAnchor],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_loadingIndicator.leadingAnchor constant:-10.0],

            [_loadingIndicator.trailingAnchor constraintEqualToAnchor:_closeButton.leadingAnchor constant:-4.0],
            [_loadingIndicator.centerYAnchor constraintEqualToAnchor:_backgroundPanel.centerYAnchor],
            [_loadingIndicator.widthAnchor constraintEqualToConstant:24.0],
            [_loadingIndicator.heightAnchor constraintEqualToConstant:24.0],

            [_closeButton.trailingAnchor constraintEqualToAnchor:_backgroundPanel.trailingAnchor constant:-8.0],
            [_closeButton.centerYAnchor constraintEqualToAnchor:_backgroundPanel.centerYAnchor],
            [_closeButton.widthAnchor constraintEqualToConstant:40.0],
            [_closeButton.heightAnchor constraintEqualToConstant:40.0],
        ]];
        [self refreshAppearance];
    }
    return self;
}

- (void)handleCloseButton:(BrowserTabCloseButton *)button {
    (void)button;
    [self.delegate compactTabCellDidRequestClose:self];
}

- (BOOL)containsCloseButtonAtPoint:(CGPoint)point {
    CGPoint closePoint = [self.closeButton convertPoint:point fromView:self];
    return [self.closeButton pointInside:closePoint withEvent:nil];
}

- (BOOL)handleCloseButtonAtPoint:(CGPoint)point {
    if (![self containsCloseButtonAtPoint:point]) {
        return NO;
    }
    [self.closeButton sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
    return YES;
}

- (CGPoint)closeButtonCenterInView:(UIView *)view {
    return [self.closeButton.superview convertPoint:self.closeButton.center toView:view];
}

- (BOOL)canBecomeFocused {
    return self.chromeFocusEnabled;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.tabIdentifier = @"";
    self.selectedTab = NO;
    self.transform = CGAffineTransformIdentity;
    [self.loadingIndicator stopAnimating];
    [self refreshAppearance];
}

- (void)configureWithTab:(BrowserTabViewModel *)tab
                selected:(BOOL)selected
                 loading:(BOOL)loading {
    self.tabIdentifier = tab.identifier ?: @"";
    self.selectedTab = selected;
    self.titleLabel.text = tab.title.length > 0 ? tab.title :
        (tab.URLString.length > 0 ? tab.URLString : @"New Tab");
    if (loading) {
        [self.loadingIndicator startAnimating];
    } else {
        [self.loadingIndicator stopAnimating];
    }
    [self refreshAppearance];
}

- (void)refreshAppearance {
    BOOL focused = self.isFocused;
    self.backgroundPanel.backgroundColor = focused
        ? [BrowserAppearance focusedControlColor]
        : (self.isSelectedTab ? [BrowserAppearance activeTabColor] : [BrowserAppearance inactiveTabColor]);
    self.backgroundPanel.layer.borderColor = focused
        ? [BrowserAppearance focusedBorderColor].CGColor
        : (self.isSelectedTab
            ? [BrowserAppearance chromeBorderColor].CGColor
            : [BrowserAppearance controlBorderColor].CGColor);
    self.backgroundPanel.layer.borderWidth = focused ? 2.0 : 1.0;
    self.titleLabel.textColor = (focused || self.isSelectedTab)
        ? [BrowserAppearance primaryTextColor]
        : [BrowserAppearance secondaryTextColor];
    self.faviconView.tintColor = focused || self.isSelectedTab
        ? [BrowserAppearance primaryTextColor]
        : [BrowserAppearance secondaryTextColor];
    self.closeButton.tintColor = focused || self.isSelectedTab
        ? [BrowserAppearance primaryTextColor]
        : [BrowserAppearance secondaryTextColor];
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context
       withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    [coordinator addCoordinatedAnimations:^{
        self.transform = self.isFocused
            ? CGAffineTransformMakeScale(BrowserChromeFocusedScale(), BrowserChromeFocusedScale())
            : CGAffineTransformIdentity;
        [self refreshAppearance];
    } completion:nil];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    UIPress *press = presses.anyObject;
    if (press != nil && press.type == UIPressTypePlayPause && self.isFocused) {
        [self.delegate compactTabCellDidRequestClose:self];
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

@end
