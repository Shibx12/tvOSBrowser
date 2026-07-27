#import "BrowserChromeViewController.h"

#import "BrowserAppearance.h"
#import "BrowserFocusCoordinator.h"
#import "BrowserViewModel.h"
#import "CompactTabBarView.h"

static CGFloat BrowserChromeSquaredDistance(CGPoint firstPoint, CGPoint secondPoint) {
    CGFloat deltaX = firstPoint.x - secondPoint.x;
    CGFloat deltaY = firstPoint.y - secondPoint.y;
    return (deltaX * deltaX) + (deltaY * deltaY);
}

@interface BrowserChromeViewController () <
    BrowserToolbarViewDelegate,
    CompactTabBarViewDelegate
>

@property (nonatomic) BrowserViewModel *viewModel;
@property (nonatomic) UIVisualEffectView *effectView;
@property (nonatomic) UIView *tintView;
@property (nonatomic) CompactTabBarView *tabBarView;
@property (nonatomic) BrowserToolbarView *toolbarView;
@property (nonatomic) BrowserFocusCoordinator *focusCoordinator;
@property (nonatomic, readwrite, getter=isChromeVisible) BOOL chromeVisible;
@property (nonatomic, readwrite, getter=isFocusModeActive) BOOL focusModeActive;
@property (nonatomic, readwrite, getter=isChromeAutoHidden) BOOL chromeAutoHidden;
@property (nonatomic) CGRect lastShadowBounds;

@end

@implementation BrowserChromeViewController

- (instancetype)initWithViewModel:(BrowserViewModel *)viewModel {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = viewModel;
        _focusCoordinator = [BrowserFocusCoordinator new];
        _chromeVisible = YES;
        _focusModeActive = NO;
        _chromeAutoHidden = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.clipsToBounds = NO;
    self.view.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.view.layer.shadowRadius = 16.0;
    self.view.layer.shadowOpacity = 0.20;

    self.effectView = [[UIVisualEffectView alloc] initWithEffect:[BrowserAppearance chromeBlurEffect]];
    self.effectView.translatesAutoresizingMaskIntoConstraints = NO;
    self.effectView.layer.cornerRadius = 22.0;
    self.effectView.layer.borderWidth = 1.0;
    self.effectView.layer.masksToBounds = YES;
    [self.view addSubview:self.effectView];

    self.tintView = [UIView new];
    self.tintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tintView.userInteractionEnabled = NO;
    [self.effectView.contentView addSubview:self.tintView];

    self.tabBarView = [[CompactTabBarView alloc] initWithViewModel:self.viewModel];
    self.tabBarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabBarView.delegate = self;
    [self.effectView.contentView addSubview:self.tabBarView];

    self.toolbarView = [BrowserToolbarView new];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolbarView.delegate = self;
    [self.effectView.contentView addSubview:self.toolbarView];

    [NSLayoutConstraint activateConstraints:@[
        [self.effectView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.effectView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.effectView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.effectView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.tintView.leadingAnchor constraintEqualToAnchor:self.effectView.contentView.leadingAnchor],
        [self.tintView.trailingAnchor constraintEqualToAnchor:self.effectView.contentView.trailingAnchor],
        [self.tintView.topAnchor constraintEqualToAnchor:self.effectView.contentView.topAnchor],
        [self.tintView.bottomAnchor constraintEqualToAnchor:self.effectView.contentView.bottomAnchor],

        [self.tabBarView.leadingAnchor constraintEqualToAnchor:self.effectView.contentView.leadingAnchor constant:18.0],
        [self.tabBarView.trailingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:-14.0],
        [self.tabBarView.centerYAnchor constraintEqualToAnchor:self.effectView.contentView.centerYAnchor],
        [self.tabBarView.heightAnchor constraintEqualToConstant:68.0],

        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.effectView.contentView.trailingAnchor constant:-18.0],
        [self.toolbarView.centerYAnchor constraintEqualToAnchor:self.effectView.contentView.centerYAnchor],
        [self.toolbarView.heightAnchor constraintEqualToConstant:58.0],
        [self.toolbarView.widthAnchor constraintEqualToConstant:412.0],
    ]];

    [self applyCurrentAppearance];
    [self setFocusModeActive:NO];
    [self.tabBarView applyViewModelUpdate];

    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
    [notificationCenter addObserver:self
                           selector:@selector(handleAccessibilityAppearanceDidChange:)
                               name:UIAccessibilityReduceTransparencyStatusDidChangeNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(handleAccessibilityAppearanceDidChange:)
                               name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(handleAccessibilityAppearanceDidChange:)
                               name:UIAccessibilityReduceMotionStatusDidChangeNotification
                             object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!CGRectEqualToRect(self.lastShadowBounds, self.view.bounds)) {
        self.lastShadowBounds = self.view.bounds;
        self.view.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.view.bounds cornerRadius:22.0].CGPath;
    }
}

- (void)handleAccessibilityAppearanceDidChange:(NSNotification *)notification {
    (void)notification;
    [self applyCurrentAppearance];
}

- (void)applyCurrentAppearance {
    self.effectView.effect = [BrowserAppearance chromeBlurEffect];
    self.tintView.backgroundColor = [BrowserAppearance chromeFallbackColor];
    self.effectView.layer.borderColor = [BrowserAppearance chromeBorderColor].CGColor;
    self.view.layer.shadowColor = [BrowserAppearance chromeShadowColor].CGColor;
    self.view.layer.shadowOpacity = UIAccessibilityIsReduceTransparencyEnabled() ? 0.10 : 0.20;
    [self.tabBarView refreshAppearance];
    [self.toolbarView refreshAppearance];
}

- (void)updateWithTitle:(NSString *)title
              URLString:(NSString *)URLString
                loading:(BOOL)loading
              canGoBack:(BOOL)canGoBack
           canGoForward:(BOOL)canGoForward {
    (void)title;
    (void)URLString;
    [self.tabBarView applyViewModelUpdate];
    [self.toolbarView updateCanGoBack:canGoBack canGoForward:canGoForward loading:loading];
}

- (void)setChromeVisible:(BOOL)visible {
    _chromeVisible = visible;
    [self setChromeAutoHidden:NO animated:NO];
    self.view.hidden = !visible;
    if (!visible) {
        [self setFocusModeActive:NO];
    }
}

- (void)setChromeAutoHidden:(BOOL)autoHidden animated:(BOOL)animated {
    if (_chromeAutoHidden == autoHidden) {
        return;
    }
    _chromeAutoHidden = autoHidden;

    if (!self.chromeVisible) {
        self.view.transform = CGAffineTransformIdentity;
        self.view.alpha = 1.0;
        self.view.userInteractionEnabled = NO;
        return;
    }

    if (!autoHidden) {
        self.view.userInteractionEnabled = YES;
    } else {
        [self setFocusModeActive:NO];
        self.view.userInteractionEnabled = NO;
    }

    CGFloat hiddenOffset = -(CGRectGetHeight(self.view.bounds) + 40.0);
    void (^changes)(void) = ^{
        self.view.transform = autoHidden
            ? CGAffineTransformMakeTranslation(0.0, hiddenOffset)
            : CGAffineTransformIdentity;
        self.view.alpha = autoHidden ? 0.0 : 1.0;
    };
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        [self.view.layer removeAllAnimations];
        changes();
        return;
    }

    [UIView animateWithDuration:0.32
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseInOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

- (void)setFocusModeActive:(BOOL)focusModeActive {
    _focusModeActive = focusModeActive;
    self.tabBarView.chromeFocusEnabled = focusModeActive;
    self.toolbarView.chromeFocusEnabled = focusModeActive;
    if (!focusModeActive) {
        [self.focusCoordinator reset];
    }
}

- (UIView *)preferredFocusItem {
    UIView *fallback = [self.tabBarView preferredFocusItem];
    return [self.focusCoordinator preferredFocusItemWithFallback:fallback];
}

- (BOOL)shouldExitChromeForDownPress {
    return [self.focusCoordinator shouldExitChromeForDownPress];
}

- (BOOL)containsInteractiveControlAtPoint:(CGPoint)point {
    if (self.chromeAutoHidden || !self.chromeVisible) {
        return NO;
    }
    CGPoint tabPoint = [self.tabBarView convertPoint:point fromView:self.view];
    if ([self.tabBarView containsInteractiveControlAtPoint:tabPoint]) {
        return YES;
    }

    CGPoint toolbarPoint = [self.toolbarView convertPoint:point fromView:self.view];
    return [self.toolbarView containsInteractiveControlAtPoint:toolbarPoint];
}

- (BOOL)handlePrimaryActionAtPoint:(CGPoint)point {
    if (self.chromeAutoHidden || !self.chromeVisible) {
        return NO;
    }
    CGPoint tabPoint = [self.tabBarView convertPoint:point fromView:self.view];
    if ([self.tabBarView handlePrimaryActionAtPoint:tabPoint]) {
        return YES;
    }

    CGPoint toolbarPoint = [self.toolbarView convertPoint:point fromView:self.view];
    return [self.toolbarView handlePrimaryActionAtPoint:toolbarPoint];
}

- (BOOL)getMagnetPoint:(CGPoint *)magnetPoint
              forPoint:(CGPoint)point
       maximumDistance:(CGFloat)maximumDistance {
    if (self.chromeAutoHidden || !self.chromeVisible) {
        return NO;
    }
    CGPoint bestPoint = CGPointZero;
    CGFloat bestSquaredDistance = maximumDistance * maximumDistance;
    BOOL foundCandidate = NO;

    CGPoint tabPoint = [self.tabBarView convertPoint:point fromView:self.view];
    CGPoint tabMagnetPoint = CGPointZero;
    if ([self.tabBarView getMagnetPoint:&tabMagnetPoint
                               forPoint:tabPoint
                        maximumDistance:maximumDistance]) {
        CGPoint chromeTabPoint = [self.view convertPoint:tabMagnetPoint fromView:self.tabBarView];
        bestPoint = chromeTabPoint;
        bestSquaredDistance = BrowserChromeSquaredDistance(point, chromeTabPoint);
        foundCandidate = YES;
    }

    CGPoint toolbarPoint = [self.toolbarView convertPoint:point fromView:self.view];
    CGPoint toolbarMagnetPoint = CGPointZero;
    if ([self.toolbarView getMagnetPoint:&toolbarMagnetPoint
                                forPoint:toolbarPoint
                         maximumDistance:maximumDistance]) {
        CGPoint chromeToolbarPoint = [self.view convertPoint:toolbarMagnetPoint fromView:self.toolbarView];
        CGFloat toolbarSquaredDistance = BrowserChromeSquaredDistance(point, chromeToolbarPoint);
        if (!foundCandidate || toolbarSquaredDistance < bestSquaredDistance) {
            bestPoint = chromeToolbarPoint;
            bestSquaredDistance = toolbarSquaredDistance;
            foundCandidate = YES;
        }
    }

    if (foundCandidate && magnetPoint != NULL) {
        *magnetPoint = bestPoint;
    }
    return foundCandidate;
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    UIView *preferredItem = [self preferredFocusItem];
    return preferredItem != nil ? @[preferredItem] : [super preferredFocusEnvironments];
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context
       withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    (void)coordinator;
    UIView *nextFocusedView = [context.nextFocusedItem isKindOfClass:UIView.class]
        ? (UIView *)context.nextFocusedItem
        : nil;
    if ([self.tabBarView containsFocusedItem:nextFocusedView]) {
        [self.focusCoordinator recordFocusedItem:nextFocusedView region:BrowserFocusRegionTabs];
    } else if ([self.toolbarView containsFocusedItem:nextFocusedView]) {
        [self.focusCoordinator recordFocusedItem:nextFocusedView region:BrowserFocusRegionToolbar];
    }
}

#pragma mark - CompactTabBarViewDelegate

- (void)compactTabBarView:(CompactTabBarView *)tabBarView didSelectTabAtIndex:(NSInteger)tabIndex {
    (void)tabBarView;
    if (tabIndex == self.viewModel.activeTabIndex) {
        [self.delegate browserChromeViewControllerDidRequestAddressInput:self];
        return;
    }
    [self.delegate browserChromeViewController:self didSelectTabAtIndex:tabIndex];
}

- (void)compactTabBarView:(CompactTabBarView *)tabBarView didRequestCloseTabAtIndex:(NSInteger)tabIndex {
    (void)tabBarView;
    [self.delegate browserChromeViewController:self didRequestCloseTabAtIndex:tabIndex];
}

#pragma mark - BrowserToolbarViewDelegate

- (void)browserToolbarView:(BrowserToolbarView *)toolbarView
          didTriggerAction:(BrowserChromeAction)action {
    (void)toolbarView;
    [self.delegate browserChromeViewController:self didTriggerAction:action];
}

@end
