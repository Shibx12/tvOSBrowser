#import "BrowserToolbarView.h"

#import "BrowserAnimationConstants.h"
#import "BrowserAppearance.h"

static CGFloat BrowserToolbarSquaredDistance(CGPoint firstPoint, CGPoint secondPoint) {
    CGFloat deltaX = firstPoint.x - secondPoint.x;
    CGFloat deltaY = firstPoint.y - secondPoint.y;
    return (deltaX * deltaX) + (deltaY * deltaY);
}

@interface BrowserToolbarButton : UIButton

@property (nonatomic) BrowserChromeAction chromeAction;
@property (nonatomic, getter=isChromeFocusEnabled) BOOL chromeFocusEnabled;

- (void)refreshAppearance;

@end

@implementation BrowserToolbarButton

- (BOOL)canBecomeFocused {
    return self.chromeFocusEnabled && self.enabled;
}

- (void)refreshAppearance {
    BOOL focused = self.isFocused;
    self.backgroundColor = focused ? [BrowserAppearance focusedControlColor] : UIColor.clearColor;
    self.layer.borderColor = focused
        ? [BrowserAppearance focusedBorderColor].CGColor
        : UIColor.clearColor.CGColor;
    self.layer.borderWidth = focused ? 2.0 : 0.0;
    self.tintColor = self.enabled
        ? (focused ? [BrowserAppearance primaryTextColor] : [BrowserAppearance secondaryTextColor])
        : [BrowserAppearance disabledTextColor];
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

@end

@interface BrowserToolbarView ()

@property (nonatomic) UIStackView *stackView;
@property (nonatomic, copy) NSArray<BrowserToolbarButton *> *buttons;
@property (nonatomic) BrowserToolbarButton *backButton;
@property (nonatomic) BrowserToolbarButton *forwardButton;
@property (nonatomic) BrowserToolbarButton *reloadButton;

@end

@implementation BrowserToolbarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;

        NSArray<NSDictionary *> *items = @[
            @{@"symbol": @"chevron.backward", @"label": @"Back", @"action": @(BrowserChromeActionBack)},
            @{@"symbol": @"chevron.forward", @"label": @"Forward", @"action": @(BrowserChromeActionForward)},
            @{@"symbol": @"arrow.clockwise", @"label": @"Reload", @"action": @(BrowserChromeActionReload)},
            @{@"symbol": @"house", @"label": @"Home", @"action": @(BrowserChromeActionHome)},
            @{@"symbol": @"plus", @"label": @"New Tab", @"action": @(BrowserChromeActionNewTab)},
            @{@"symbol": @"ellipsis", @"label": @"More", @"action": @(BrowserChromeActionMenu)},
        ];

        NSMutableArray<BrowserToolbarButton *> *buttons = [NSMutableArray arrayWithCapacity:items.count];
        for (NSDictionary *item in items) {
            BrowserToolbarButton *button = [BrowserToolbarButton buttonWithType:UIButtonTypeCustom];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            button.chromeAction = [item[@"action"] integerValue];
            button.chromeFocusEnabled = NO;
            button.accessibilityLabel = item[@"label"];
            UIImageSymbolConfiguration *configuration =
                [UIImageSymbolConfiguration configurationWithPointSize:25.0 weight:UIImageSymbolWeightSemibold];
            UIImage *image = [UIImage systemImageNamed:item[@"symbol"] withConfiguration:configuration];
            [button setImage:image forState:UIControlStateNormal];
            button.layer.cornerRadius = 17.0;
            button.clipsToBounds = YES;
            [button addTarget:self action:@selector(handleButton:) forControlEvents:UIControlEventPrimaryActionTriggered];
            [button.widthAnchor constraintEqualToConstant:62.0].active = YES;
            [button.heightAnchor constraintEqualToConstant:58.0].active = YES;
            [button refreshAppearance];
            [buttons addObject:button];
        }
        self.buttons = buttons;
        self.backButton = buttons[0];
        self.forwardButton = buttons[1];
        self.reloadButton = buttons[2];

        _stackView = [[UIStackView alloc] initWithArrangedSubviews:buttons];
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;
        _stackView.axis = UILayoutConstraintAxisHorizontal;
        _stackView.alignment = UIStackViewAlignmentCenter;
        _stackView.distribution = UIStackViewDistributionFill;
        _stackView.spacing = 8.0;
        [self addSubview:_stackView];

        [NSLayoutConstraint activateConstraints:@[
            [_stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)handleButton:(BrowserToolbarButton *)button {
    [self.delegate browserToolbarView:self didTriggerAction:button.chromeAction];
}

- (void)setChromeFocusEnabled:(BOOL)chromeFocusEnabled {
    _chromeFocusEnabled = chromeFocusEnabled;
    for (BrowserToolbarButton *button in self.buttons) {
        button.chromeFocusEnabled = chromeFocusEnabled;
        button.userInteractionEnabled = chromeFocusEnabled;
        if (!chromeFocusEnabled) {
            button.transform = CGAffineTransformIdentity;
        }
        [button refreshAppearance];
    }
}

- (void)updateCanGoBack:(BOOL)canGoBack
           canGoForward:(BOOL)canGoForward
                loading:(BOOL)loading {
    self.backButton.enabled = canGoBack;
    self.forwardButton.enabled = canGoForward;
    self.reloadButton.accessibilityLabel = loading ? @"Reload Loading Page" : @"Reload";
    [self refreshAppearance];
}

- (UIView *)preferredFocusItem {
    for (BrowserToolbarButton *button in self.buttons) {
        if (button.enabled && button.chromeFocusEnabled) {
            return button;
        }
    }
    return nil;
}

- (BOOL)containsFocusedItem:(UIView *)focusedItem {
    return focusedItem != nil && [focusedItem isDescendantOfView:self];
}

- (BrowserToolbarButton *)interactiveButtonAtPoint:(CGPoint)point {
    for (BrowserToolbarButton *button in self.buttons) {
        if (!button.enabled || button.hidden || button.alpha < 0.01) {
            continue;
        }
        CGPoint buttonPoint = [button convertPoint:point fromView:self];
        if ([button pointInside:buttonPoint withEvent:nil]) {
            return button;
        }
    }
    return nil;
}

- (BOOL)containsInteractiveControlAtPoint:(CGPoint)point {
    return [self interactiveButtonAtPoint:point] != nil;
}

- (BOOL)handlePrimaryActionAtPoint:(CGPoint)point {
    BrowserToolbarButton *button = [self interactiveButtonAtPoint:point];
    if (button == nil) {
        return NO;
    }
    [button sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
    return YES;
}

- (BOOL)getMagnetPoint:(CGPoint *)magnetPoint
              forPoint:(CGPoint)point
       maximumDistance:(CGFloat)maximumDistance {
    CGFloat bestSquaredDistance = maximumDistance * maximumDistance;
    CGPoint bestPoint = CGPointZero;
    BOOL foundCandidate = NO;

    for (BrowserToolbarButton *button in self.buttons) {
        if (!button.enabled || button.hidden || button.alpha < 0.01) {
            continue;
        }
        CGPoint buttonCenter = [button.superview convertPoint:button.center toView:self];
        CGFloat squaredDistance = BrowserToolbarSquaredDistance(point, buttonCenter);
        if (squaredDistance <= bestSquaredDistance) {
            bestSquaredDistance = squaredDistance;
            bestPoint = buttonCenter;
            foundCandidate = YES;
        }
    }

    if (foundCandidate && magnetPoint != NULL) {
        *magnetPoint = bestPoint;
    }
    return foundCandidate;
}

- (void)refreshAppearance {
    for (BrowserToolbarButton *button in self.buttons) {
        [button refreshAppearance];
    }
}

@end
