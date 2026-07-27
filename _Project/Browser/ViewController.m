//
//  ViewController.m
//  Browser
//
//  Created by Steven Troughton-Smith on 20/09/2015.
//  Improved by Jip van Akker on 14/10/2015 through 10/01/2019
//

#import "BrowserAddressInterpreter.h"
#import "BrowserChromeViewController.h"
#import "BrowserDOMInteractionService.h"
#import "BrowserFavoritesHomeViewController.h"
#import "BrowserMenuCoordinator.h"
#import "BrowserNavigationService.h"
#import "BrowserPageActionCoordinator.h"
#import "BrowserPreferencesStore.h"
#import "BrowserRemoteInputController.h"
#import "BrowserSessionStore.h"
#import "BrowserTabViewModel.h"
#import "BrowserTabCoordinator.h"
#import "BrowserVideoPlaybackCoordinator.h"
#import "BrowserViewModel.h"
#import "ViewController.h"

static NSString * const kBrowserGlobalSelectPressEndedNotification = @"BrowserGlobalSelectPressEndedNotification";

static CGPoint BrowserSmoothMagnetPoint(CGPoint cursorPoint,
                                        CGPoint targetPoint,
                                        CGFloat captureRadius) {
    CGFloat deltaX = targetPoint.x - cursorPoint.x;
    CGFloat deltaY = targetPoint.y - cursorPoint.y;
    CGFloat distance = hypot(deltaX, deltaY);
    if (captureRadius <= 0.0 || distance >= captureRadius) {
        return cursorPoint;
    }

    CGFloat proximity = 1.0 - (distance / captureRadius);
    CGFloat smoothProximity = proximity * proximity * (3.0 - (2.0 * proximity));
    CGFloat attraction = smoothProximity * 0.84;
    return CGPointMake(cursorPoint.x + (deltaX * attraction),
                       cursorPoint.y + (deltaY * attraction));
}

@interface ViewController () <BrowserChromeViewControllerDelegate, BrowserFavoritesHomeViewControllerDelegate, BrowserMenuCoordinatorHost, BrowserPageActionCoordinatorHost, BrowserRemoteInputControllerHost, BrowserTabCoordinatorHost, BrowserVideoPlaybackCoordinatorHost>

@property (nonatomic) BrowserAddressInterpreter *addressInterpreter;
@property (nonatomic) BrowserChromeViewController *chromeViewController;
@property (nonatomic) BrowserDOMInteractionService *domInteractionService;
@property (nonatomic) BrowserFavoritesHomeViewController *favoritesHomeViewController;
@property (nonatomic) BrowserMenuCoordinator *menuCoordinator;
@property (nonatomic) BrowserNavigationService *navigationService;
@property (nonatomic) BrowserPageActionCoordinator *pageActionCoordinator;
@property (nonatomic) BrowserPreferencesStore *preferencesStore;
@property (nonatomic) BrowserRemoteInputController *remoteInputController;
@property (nonatomic) BrowserSessionStore *sessionStore;
@property (nonatomic) BrowserTabCoordinator *tabCoordinator;
@property (nonatomic) BrowserVideoPlaybackCoordinator *videoPlaybackCoordinator;
@property (nonatomic) BrowserViewModel *viewModel;
@property (nonatomic) BOOL scrollViewAllowBounces;
@property (nonatomic, getter=isTopBarFocusActive) BOOL topBarFocusActive;
@property (nonatomic) CGFloat chromeScrollAccumulator;
@property (nonatomic, getter=isPageZoomed) BOOL pageZoomed;
@property (nonatomic, weak) BrowserWebView *zoomedWebView;
@property (nonatomic) BOOL browserContainerClipsBeforeZoom;
@property (nonatomic) UITextField *activeAddressInputTextField;

@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.definesPresentationContext = YES;
    self.scrollViewAllowBounces = YES;

    self.preferencesStore = [BrowserPreferencesStore new];
    [self.preferencesStore ensureUserAgentConsistency];

    self.viewModel = [BrowserViewModel new];
    self.viewModel.textFontSize = self.preferencesStore.textFontSize;
    self.viewModel.fullscreenVideoPlaybackEnabled = self.preferencesStore.fullscreenVideoPlaybackEnabled;

    self.addressInterpreter = [BrowserAddressInterpreter new];
    [self installBrowserChrome];
    self.domInteractionService = [BrowserDOMInteractionService new];
    self.navigationService = [[BrowserNavigationService alloc] initWithPreferencesStore:self.preferencesStore];
    self.sessionStore = [BrowserSessionStore new];
    self.menuCoordinator = [[BrowserMenuCoordinator alloc] initWithHost:self preferencesStore:self.preferencesStore];
    self.remoteInputController = [[BrowserRemoteInputController alloc] initWithHost:self rootView:self.view];
    [self.view addSubview:self.remoteInputController.cursorView];
    self.videoPlaybackCoordinator = [[BrowserVideoPlaybackCoordinator alloc] initWithHost:self
                                                                      domInteractionService:self.domInteractionService];
    self.tabCoordinator = [[BrowserTabCoordinator alloc] initWithHost:self
                                                             viewModel:self.viewModel
                                                      preferencesStore:self.preferencesStore
                                                     navigationService:self.navigationService
                                                          sessionStore:self.sessionStore
                                                    browserContainerView:self.browserContainerView
                                                              rootView:self.view
                                                            cursorView:self.remoteInputController.cursorView
                                               manualScrollPanRecognizer:self.remoteInputController.manualScrollPanRecognizer
                                                           webViewDelegate:self
                                                       scrollViewAllowBounces:self.scrollViewAllowBounces];
    self.pageActionCoordinator = [[BrowserPageActionCoordinator alloc] initWithHost:self
                                                               domInteractionService:self.domInteractionService
                                                                   navigationService:self.navigationService
                                                            videoPlaybackCoordinator:self.videoPlaybackCoordinator];
    [self installFavoritesHome];

    [self.chromeViewController setChromeVisible:YES];
    self.remoteInputController.cursorView.hidden = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGlobalSelectPressEndedNotification:)
                                                 name:kBrowserGlobalSelectPressEndedNotification
                                               object:nil];

    [self.tabCoordinator restoreInitialStateOrCreateFirstTab];
    [self refreshBrowserChrome];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tabCoordinator webViewDidAppear];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)handleApplicationWillResignActive:(NSNotification *)notification {
    (void)notification;
    [self.tabCoordinator persistSession];
}

- (void)handleApplicationDidEnterBackground:(NSNotification *)notification {
    (void)notification;
    [self.tabCoordinator persistSession];
}

- (void)handleApplicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.tabCoordinator persistSession];
}

- (void)handleGlobalSelectPressEndedNotification:(NSNotification *)notification {
    (void)notification;
    [self.remoteInputController handleGlobalSelectPressEndedNotification];
}

#pragma mark - Helpers

- (void)installBrowserChrome {
    BrowserChromeViewController *chromeViewController =
        [[BrowserChromeViewController alloc] initWithViewModel:self.viewModel];
    chromeViewController.delegate = self;
    [self addChildViewController:chromeViewController];
    chromeViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:chromeViewController.view];
    [NSLayoutConstraint activateConstraints:@[
        [chromeViewController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:80.0],
        [chromeViewController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-80.0],
        [chromeViewController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:32.0],
        [chromeViewController.view.heightAnchor constraintEqualToConstant:88.0],
    ]];
    [chromeViewController didMoveToParentViewController:self];
    self.chromeViewController = chromeViewController;
}

- (void)installFavoritesHome {
    BrowserFavoritesHomeViewController *viewController = [BrowserFavoritesHomeViewController new];
    viewController.delegate = self;
    [self addChildViewController:viewController];
    viewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.browserContainerView addSubview:viewController.view];
    [NSLayoutConstraint activateConstraints:@[
        [viewController.view.leadingAnchor constraintEqualToAnchor:self.browserContainerView.leadingAnchor],
        [viewController.view.trailingAnchor constraintEqualToAnchor:self.browserContainerView.trailingAnchor],
        [viewController.view.topAnchor constraintEqualToAnchor:self.browserContainerView.topAnchor],
        [viewController.view.bottomAnchor constraintEqualToAnchor:self.browserContainerView.bottomAnchor],
    ]];
    [viewController didMoveToParentViewController:self];
    viewController.view.hidden = YES;
    self.favoritesHomeViewController = viewController;
}

- (BOOL)isFavoritesHomeVisible {
    return self.favoritesHomeViewController != nil &&
        !self.favoritesHomeViewController.view.hidden;
}

- (void)updateFavoritesHomeVisibility {
    BOOL shouldShowHome = self.tabCoordinator.activeTab.showsFavoritesHome;
    self.favoritesHomeViewController.view.hidden = !shouldShowHome;
    self.webview.hidden = shouldShowHome;
    if (shouldShowHome) {
        [self.favoritesHomeViewController reloadFavorites];
        [self.browserContainerView bringSubviewToFront:self.favoritesHomeViewController.view];
        [self.chromeViewController setChromeAutoHidden:NO animated:YES];
    } else {
        [self.favoritesHomeViewController clearPointerHover];
    }
    [self.remoteInputController refreshInteractionState];
    [self.view bringSubviewToFront:self.chromeViewController.view];
    [self.view bringSubviewToFront:self.remoteInputController.cursorView];
}

- (void)refreshBrowserChrome {
    BrowserTabViewModel *tab = self.tabCoordinator.activeTab ?: self.viewModel.activeTab;
    BrowserWebView *webView = self.webview;
    NSString *title = tab.title.length > 0 ? tab.title : webView.title;
    NSString *URLString = tab.URLString.length > 0
        ? tab.URLString
        : webView.request.URL.absoluteString;
    BOOL loading = tab.isLoading || webView.isLoading;
    [self.chromeViewController updateWithTitle:title
                                     URLString:URLString
                                       loading:loading
                                     canGoBack:webView.canGoBack
                                  canGoForward:webView.canGoForward];
    [self updateFavoritesHomeVisibility];
}

- (BrowserWebView *)webview {
    return self.tabCoordinator.activeWebView;
}

- (CGPoint)browserDOMPointForCursor {
    return [self.domInteractionService DOMPointForCursorOrigin:self.remoteInputController.cursorView.frame.origin
                                                        inView:self.view
                                                       webView:self.webview];
}

- (void)loadHomePage {
    [self setPageZoomed:NO animated:YES];
    [self.tabCoordinator loadHomePage];
}

- (CGAffineTransform)pageZoomTransformForCursorPoint:(CGPoint)cursorPoint {
    CGRect viewportBounds = self.browserContainerView.bounds;
    CGFloat viewportWidth = MAX(CGRectGetWidth(viewportBounds), 1.0);
    CGFloat viewportHeight = MAX(CGRectGetHeight(viewportBounds), 1.0);
    CGPoint point = [self.browserContainerView convertPoint:cursorPoint fromView:self.view];
    CGFloat normalizedX = MIN(MAX((point.x - CGRectGetMinX(viewportBounds)) / viewportWidth, 0.0), 1.0);
    CGFloat normalizedY = MIN(MAX((point.y - CGRectGetMinY(viewportBounds)) / viewportHeight, 0.0), 1.0);

    CGAffineTransform transform = CGAffineTransformMakeScale(2.0, 2.0);
    transform.tx = (0.5 - normalizedX) * viewportWidth;
    transform.ty = (0.5 - normalizedY) * viewportHeight;
    return transform;
}

- (void)setPageZoomed:(BOOL)pageZoomed animated:(BOOL)animated {
    if (_pageZoomed == pageZoomed) {
        return;
    }

    BrowserWebView *webView = pageZoomed ? self.webview : self.zoomedWebView;
    if (webView == nil || (pageZoomed && [self isFavoritesHomeVisible])) {
        return;
    }

    _pageZoomed = pageZoomed;
    if (pageZoomed) {
        self.zoomedWebView = webView;
        self.browserContainerClipsBeforeZoom = self.browserContainerView.clipsToBounds;
        self.browserContainerView.clipsToBounds = YES;
    }

    CGPoint cursorPoint = self.remoteInputController.cursorView.frame.origin;
    CGAffineTransform targetTransform = pageZoomed
        ? [self pageZoomTransformForCursorPoint:cursorPoint]
        : CGAffineTransformIdentity;
    void (^changes)(void) = ^{
        webView.transform = targetTransform;
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        (void)finished;
        if (!pageZoomed) {
            self.browserContainerView.clipsToBounds = self.browserContainerClipsBeforeZoom;
            self.zoomedWebView = nil;
        }
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        completion(YES);
    } else {
        [UIView animateWithDuration:0.26
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:completion];
    }
    [self.view bringSubviewToFront:self.chromeViewController.view];
    [self.view bringSubviewToFront:self.remoteInputController.cursorView];
}

- (void)updatePageZoomForCursorPoint:(CGPoint)cursorPoint {
    if (!self.pageZoomed || self.zoomedWebView == nil) {
        return;
    }
    if (self.chromeViewController.isChromeVisible &&
        !self.chromeViewController.isChromeAutoHidden &&
        CGRectContainsPoint(self.chromeViewController.view.frame, cursorPoint)) {
        return;
    }
    self.zoomedWebView.transform = [self pageZoomTransformForCursorPoint:cursorPoint];
}

- (void)showAdvancedMenu {
    [self deactivateTopBarFocusMode];
    [self.menuCoordinator showAdvancedMenu];
}

- (BOOL)canActivateTopBarFocusMode {
    return self.presentedViewController == nil &&
        self.chromeViewController.isChromeVisible;
}

- (void)activateTopBarFocusMode {
    if (![self canActivateTopBarFocusMode]) {
        return;
    }
    if (self.topBarFocusActive) {
        return;
    }

    self.topBarFocusActive = YES;
    [self.chromeViewController setFocusModeActive:YES];
    [self.remoteInputController refreshInteractionState];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (void)deactivateTopBarFocusMode {
    if (!self.topBarFocusActive) {
        return;
    }

    self.topBarFocusActive = NO;
    [self.chromeViewController setFocusModeActive:NO];
    [self.remoteInputController refreshInteractionState];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (void)updateChromeAutoHideForScrollDeltaY:(CGFloat)deltaY
                              contentOffsetY:(CGFloat)contentOffsetY {
    if ([self isFavoritesHomeVisible]) {
        return;
    }
    if (!self.chromeViewController.isChromeVisible) {
        self.chromeScrollAccumulator = 0.0;
        return;
    }

    if (contentOffsetY <= 12.0) {
        self.chromeScrollAccumulator = 0.0;
        [self.chromeViewController setChromeAutoHidden:NO animated:YES];
        return;
    }

    if ((deltaY > 0.0 && self.chromeScrollAccumulator < 0.0) ||
        (deltaY < 0.0 && self.chromeScrollAccumulator > 0.0)) {
        self.chromeScrollAccumulator = 0.0;
    }
    self.chromeScrollAccumulator += deltaY;

    if (self.chromeScrollAccumulator >= 28.0) {
        self.chromeScrollAccumulator = 0.0;
        [self deactivateTopBarFocusMode];
        [self.chromeViewController setChromeAutoHidden:YES animated:YES];
    } else if (self.chromeScrollAccumulator <= -22.0) {
        self.chromeScrollAccumulator = 0.0;
        [self.chromeViewController setChromeAutoHidden:NO animated:YES];
    }
}

- (void)toggleBrowserChromeForMenuPress {
    self.chromeScrollAccumulator = 0.0;
    if (self.chromeViewController.isChromeAutoHidden) {
        [self.chromeViewController setChromeAutoHidden:NO animated:YES];
        [self.remoteInputController setCursorModeEnabled:YES];
        return;
    }
    if (!self.chromeViewController.isChromeVisible) {
        [self.chromeViewController setChromeVisible:YES];
        [self.chromeViewController setChromeAutoHidden:YES animated:NO];
        [self.chromeViewController setChromeAutoHidden:NO animated:YES];
        [self.remoteInputController setCursorModeEnabled:YES];
        return;
    }
    [self deactivateTopBarFocusMode];
    [self.chromeViewController setChromeAutoHidden:YES animated:YES];
}

- (void)performChromeAction:(BrowserChromeAction)action {
    [self deactivateTopBarFocusMode];

    switch (action) {
        case BrowserChromeActionBack:
            if (self.webview.canGoBack) {
                [self.webview goBack];
            }
            break;
        case BrowserChromeActionReload:
            [self.webview reload];
            break;
        case BrowserChromeActionForward:
            if (self.webview.canGoForward) {
                [self.webview goForward];
            }
            break;
        case BrowserChromeActionHome:
            [self loadHomePage];
            break;
        case BrowserChromeActionNewTab:
            [self setPageZoomed:NO animated:YES];
            [self.tabCoordinator createNewTabLoadingHomePage:YES];
            break;
        case BrowserChromeActionMenu:
            [self showAdvancedMenu];
            break;
    }
}

- (void)updateTextFontSize {
    if (self.webview == nil) {
        return;
    }

    NSString *jsString = [[NSString alloc] initWithFormat:
                          @"(function(){"
                           "var value='%lu%%';"
                           "var multiplier=%lu/100;"
                           "if (document.documentElement && document.documentElement.style) {"
                               "document.documentElement.style.setProperty('-webkit-text-size-adjust', value, 'important');"
                               "document.documentElement.style.setProperty('text-size-adjust', value, 'important');"
                           "}"
                           "if (document.body && document.body.style) {"
                               "document.body.style.setProperty('-webkit-text-size-adjust', value, 'important');"
                               "document.body.style.setProperty('text-size-adjust', value, 'important');"
                           "}"
                           "if (!document.body || !window.getComputedStyle) { return value; }"
                           "var elements = document.querySelectorAll('body, body *');"
                           "for (var i = 0; i < elements.length; i++) {"
                               "var element = elements[i];"
                               "if (!element || !element.tagName) { continue; }"
                               "var tagName = element.tagName.toLowerCase();"
                               "if (tagName === 'script' || tagName === 'style' || tagName === 'noscript') { continue; }"
                               "var originalSize = element.getAttribute('data-browser-original-font-size');"
                               "if (!originalSize) {"
                                   "var computedSize = window.getComputedStyle(element).fontSize || '';"
                                   "if (computedSize.indexOf('px') == -1) { continue; }"
                                   "var parsedSize = parseFloat(computedSize);"
                                   "if (!isFinite(parsedSize) || parsedSize <= 0) { continue; }"
                                   "originalSize = String(parsedSize);"
                                   "element.setAttribute('data-browser-original-font-size', originalSize);"
                               "}"
                               "var baseSize = parseFloat(originalSize);"
                               "if (!isFinite(baseSize) || baseSize <= 0) { continue; }"
                               "element.style.setProperty('font-size', (baseSize * multiplier) + 'px', 'important');"
                           "}"
                           "return value;"
                          "})()",
                          (unsigned long)self.viewModel.textFontSize,
                          (unsigned long)self.viewModel.textFontSize];
    [self.webview stringByEvaluatingJavaScriptFromString:jsString];
}

- (void)addressInputTextFieldDidFinish:(UITextField *)textField {
    if (textField != self.activeAddressInputTextField) {
        return;
    }

    NSString *addressString = textField.text;
    [textField resignFirstResponder];
    [textField removeFromSuperview];
    self.activeAddressInputTextField = nil;
    [self browserChromeViewController:self.chromeViewController
               didSubmitAddressString:addressString];
}

- (void)showInputURLorSearchGoogle {
    [self.activeAddressInputTextField resignFirstResponder];
    [self.activeAddressInputTextField removeFromSuperview];

    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(-100.0, -100.0, 1.0, 1.0)];
    textField.keyboardType = UIKeyboardTypeURL;
    textField.returnKeyType = UIReturnKeyGo;
    textField.backgroundColor = UIColor.clearColor;
    textField.borderStyle = UITextBorderStyleNone;
    textField.alpha = 0.01;
    textField.accessibilityElementsHidden = YES;
    [textField addTarget:self
                  action:@selector(addressInputTextFieldDidFinish:)
        forControlEvents:UIControlEventEditingDidEndOnExit];

    self.activeAddressInputTextField = textField;
    [self.view addSubview:textField];
    [textField becomeFirstResponder];
}

- (void)requestURLorSearchInput {
    [self showInputURLorSearchGoogle];
}

- (void)showHintsAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Usage Guide"
                                                                             message:@"Press the touch area once to click.\nDouble press to switch between cursor and scroll mode.\nTriple press to toggle 200% page zoom; move the cursor to inspect all directions.\nPress Menu to show or hide the browser controls.\nSingle tap the Play/Pause button to enter a URL or search.\nDouble tap the Play/Pause to show the Advanced Menu with more options.\nUse the × button on a tab to close it."
                                                                                     @"\nLong-press a Favorite to edit its name or URL, or delete it."
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    if (self.preferencesStore.dontShowHintsOnLaunch) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Always Show On Launch"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(__unused UIAlertAction *action) {
            weakSelf.preferencesStore.dontShowHintsOnLaunch = NO;
        }]];
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Don't Show This Again"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(__unused UIAlertAction *action) {
            weakSelf.preferencesStore.dontShowHintsOnLaunch = YES;
        }]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)browserHandlePrimaryAction {
    if (!self.remoteInputController.cursorModeEnabled || self.webview == nil) {
        return;
    }

    CGPoint cursorPoint = self.remoteInputController.cursorView.frame.origin;
    if (self.chromeViewController.isChromeVisible &&
        CGRectContainsPoint(self.chromeViewController.view.frame, cursorPoint)) {
        CGPoint chromePoint = [self.chromeViewController.view convertPoint:cursorPoint fromView:self.view];
        [self.chromeViewController handlePrimaryActionAtPoint:chromePoint];
        return;
    }

    if ([self isFavoritesHomeVisible]) {
        CGPoint homePoint =
            [self.favoritesHomeViewController.view convertPoint:cursorPoint fromView:self.view];
        [self.favoritesHomeViewController handlePrimaryActionAtPoint:homePoint];
        return;
    }

    CGPoint point = [self.view convertPoint:cursorPoint toView:self.webview];
    if (point.y < 0) {
        return;
    }

    CGPoint domPoint = [self browserDOMPointForCursor];
    [self.pageActionCoordinator handlePageSelectionAtDOMPoint:domPoint webView:self.webview];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    if (self.topBarFocusActive) {
        UIView *preferredFocusItem = [self.chromeViewController preferredFocusItem];
        if (preferredFocusItem != nil) {
            return @[preferredFocusItem];
        }
    }
    return [super preferredFocusEnvironments];
}

#pragma mark - BrowserChromeViewControllerDelegate

- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
                   didTriggerAction:(BrowserChromeAction)action {
    (void)viewController;
    [self performChromeAction:action];
}

#pragma mark - BrowserFavoritesHomeViewControllerDelegate

- (void)browserFavoritesHomeViewController:(BrowserFavoritesHomeViewController *)viewController
                        didSelectURLString:(NSString *)URLString {
    (void)viewController;
    NSURLRequest *request = [self.navigationService requestForURLString:URLString];
    if (request == nil) {
        return;
    }
    self.tabCoordinator.activeTab.showsFavoritesHome = NO;
    [self refreshBrowserChrome];
    [self.webview loadRequest:request];
}

- (void)browserFavoritesHomeViewControllerDidRequestAddFavorite:
    (BrowserFavoritesHomeViewController *)viewController {
    (void)viewController;
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"Add Website"
                                            message:@"Add a website to your Favorites home screen."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Website name";
        textField.keyboardType = UIKeyboardTypeDefault;
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"https://example.com";
        textField.keyboardType = UIKeyboardTypeURL;
    }];

    __weak typeof(self) weakSelf = self;
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Add"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction *action) {
        NSString *name = [weakSelf.addressInterpreter trimmedInput:alertController.textFields.firstObject.text];
        NSString *enteredURL = [weakSelf.addressInterpreter trimmedInput:alertController.textFields.lastObject.text];
        NSString *URLString = [weakSelf.addressInterpreter normalizedURLStringForInput:enteredURL];
        if (URLString.length == 0) {
            return;
        }
        if (name.length == 0) {
            name = [NSURL URLWithString:URLString].host ?: URLString;
        }
        NSMutableArray *favorites =
            [[NSUserDefaults.standardUserDefaults arrayForKey:@"FAVORITES"] mutableCopy] ?:
            [NSMutableArray array];
        [favorites addObject:@[URLString, name]];
        [NSUserDefaults.standardUserDefaults setObject:favorites forKey:@"FAVORITES"];
        [NSUserDefaults.standardUserDefaults synchronize];
        [NSNotificationCenter.defaultCenter postNotificationName:@"BrowserFavoritesDidChangeNotification"
                                                          object:nil];
        [weakSelf.favoritesHomeViewController reloadFavorites];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (NSInteger)favoriteIndexForExpectedIndex:(NSUInteger)expectedIndex
                                     title:(NSString *)title
                                 URLString:(NSString *)URLString
                                 favorites:(NSArray *)favorites {
    if (expectedIndex < favorites.count) {
        NSArray *entry = [favorites[expectedIndex] isKindOfClass:NSArray.class]
            ? favorites[expectedIndex]
            : nil;
        NSString *entryURL = entry.count > 0 && [entry[0] isKindOfClass:NSString.class] ? entry[0] : @"";
        NSString *entryTitle = entry.count > 1 && [entry[1] isKindOfClass:NSString.class] ? entry[1] : @"";
        if ([entryURL isEqualToString:URLString] && [entryTitle isEqualToString:title]) {
            return (NSInteger)expectedIndex;
        }
    }

    for (NSUInteger index = 0; index < favorites.count; index++) {
        NSArray *entry = [favorites[index] isKindOfClass:NSArray.class] ? favorites[index] : nil;
        NSString *entryURL = entry.count > 0 && [entry[0] isKindOfClass:NSString.class] ? entry[0] : @"";
        NSString *entryTitle = entry.count > 1 && [entry[1] isKindOfClass:NSString.class] ? entry[1] : @"";
        if ([entryURL isEqualToString:URLString] && [entryTitle isEqualToString:title]) {
            return (NSInteger)index;
        }
    }
    return NSNotFound;
}

- (void)saveFavorites:(NSArray *)favorites {
    [NSUserDefaults.standardUserDefaults setObject:favorites forKey:@"FAVORITES"];
    [NSUserDefaults.standardUserDefaults synchronize];
    [NSNotificationCenter.defaultCenter postNotificationName:@"BrowserFavoritesDidChangeNotification"
                                                      object:nil];
}

- (void)presentFavoriteNameEditorAtIndex:(NSUInteger)expectedIndex
                                   title:(NSString *)title
                               URLString:(NSString *)URLString {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"Edit Name"
                                            message:URLString
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = title;
        textField.placeholder = @"Website name";
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    __weak typeof(self) weakSelf = self;
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Save"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction *action) {
        NSMutableArray *favorites =
            [[NSUserDefaults.standardUserDefaults arrayForKey:@"FAVORITES"] mutableCopy] ?:
            [NSMutableArray array];
        NSInteger index = [weakSelf favoriteIndexForExpectedIndex:expectedIndex
                                                            title:title
                                                        URLString:URLString
                                                        favorites:favorites];
        if (index == NSNotFound) {
            return;
        }
        NSString *updatedTitle =
            [weakSelf.addressInterpreter trimmedInput:alertController.textFields.firstObject.text];
        if (updatedTitle.length == 0) {
            updatedTitle = [NSURL URLWithString:URLString].host ?: URLString;
        }
        favorites[(NSUInteger)index] = @[URLString, updatedTitle];
        [weakSelf saveFavorites:favorites];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)presentFavoriteURLEditorAtIndex:(NSUInteger)expectedIndex
                                  title:(NSString *)title
                              URLString:(NSString *)URLString {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"Edit URL"
                                            message:title
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = URLString;
        textField.placeholder = @"https://example.com";
        textField.keyboardType = UIKeyboardTypeURL;
    }];

    __weak typeof(self) weakSelf = self;
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Save"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction *action) {
        NSString *enteredURL =
            [weakSelf.addressInterpreter trimmedInput:alertController.textFields.firstObject.text];
        NSString *updatedURL =
            [weakSelf.addressInterpreter normalizedURLStringForInput:enteredURL];
        if (updatedURL.length == 0) {
            return;
        }
        NSMutableArray *favorites =
            [[NSUserDefaults.standardUserDefaults arrayForKey:@"FAVORITES"] mutableCopy] ?:
            [NSMutableArray array];
        NSInteger index = [weakSelf favoriteIndexForExpectedIndex:expectedIndex
                                                            title:title
                                                        URLString:URLString
                                                        favorites:favorites];
        if (index == NSNotFound) {
            return;
        }
        favorites[(NSUInteger)index] = @[updatedURL, title];
        [weakSelf saveFavorites:favorites];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)browserFavoritesHomeViewController:(BrowserFavoritesHomeViewController *)viewController
       didRequestActionsForFavoriteAtIndex:(NSUInteger)index
                                     title:(NSString *)title
                                 URLString:(NSString *)URLString {
    (void)viewController;
    NSString *displayTitle = title.length > 0 ? title : URLString;
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:displayTitle
                                            message:URLString
                                     preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alertController addAction:[UIAlertAction actionWithTitle:@"Edit Name"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction *action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf presentFavoriteNameEditorAtIndex:index
                                                 title:title
                                             URLString:URLString];
        });
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Edit URL"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction *action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf presentFavoriteURLEditorAtIndex:index
                                                title:title
                                            URLString:URLString];
        });
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Delete"
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(__unused UIAlertAction *action) {
        NSMutableArray *favorites =
            [[NSUserDefaults.standardUserDefaults arrayForKey:@"FAVORITES"] mutableCopy] ?:
            [NSMutableArray array];
        NSInteger resolvedIndex = [weakSelf favoriteIndexForExpectedIndex:index
                                                                     title:title
                                                                 URLString:URLString
                                                                 favorites:favorites];
        if (resolvedIndex == NSNotFound) {
            return;
        }
        [favorites removeObjectAtIndex:(NSUInteger)resolvedIndex];
        [weakSelf saveFavorites:favorites];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
                didSelectTabAtIndex:(NSInteger)tabIndex {
    (void)viewController;
    [self setPageZoomed:NO animated:YES];
    [self.tabCoordinator switchToTabAtIndex:tabIndex];
    [self refreshBrowserChrome];
}

- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
           didRequestCloseTabAtIndex:(NSInteger)tabIndex {
    (void)viewController;
    if (tabIndex == self.viewModel.activeTabIndex) {
        [self setPageZoomed:NO animated:YES];
    }
    [self.tabCoordinator closeTabAtIndex:tabIndex];
    [self refreshBrowserChrome];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (void)browserChromeViewControllerDidRequestAddressInput:(BrowserChromeViewController *)viewController {
    (void)viewController;
    [self deactivateTopBarFocusMode];
    [self requestURLorSearchInput];
}

- (void)browserChromeViewController:(BrowserChromeViewController *)viewController
             didSubmitAddressString:(NSString *)addressString {
    (void)viewController;
    NSString *trimmedInput = [self.addressInterpreter trimmedInput:addressString];
    if (trimmedInput.length == 0) {
        return;
    }

    NSURLRequest *request = nil;
    NSString *URLString = [self.addressInterpreter normalizedURLStringForInput:trimmedInput];
    if (URLString.length > 0) {
        request = [self.navigationService requestForURLString:URLString];
    } else {
        request = [self.navigationService googleSearchRequestForQuery:trimmedInput];
    }
    if (request != nil) {
        [self setPageZoomed:NO animated:YES];
        [self.webview loadRequest:request];
    }
}

#pragma mark - BrowserMenuCoordinatorHost

- (BrowserWebView *)browserWebView {
    return self.webview;
}

- (NSString *)browserPreviousURL {
    return self.tabCoordinator.previousURL;
}

- (void)setBrowserPreviousURL:(NSString *)browserPreviousURL {
    self.tabCoordinator.previousURL = browserPreviousURL ?: @"";
}

- (NSUInteger)browserTextFontSize {
    return self.viewModel.textFontSize;
}

- (void)setBrowserTextFontSize:(NSUInteger)browserTextFontSize {
    self.viewModel.textFontSize = browserTextFontSize;
    self.preferencesStore.textFontSize = self.viewModel.textFontSize;
}

- (BOOL)browserFullscreenVideoPlaybackEnabled {
    return self.viewModel.fullscreenVideoPlaybackEnabled;
}

- (void)setBrowserFullscreenVideoPlaybackEnabled:(BOOL)browserFullscreenVideoPlaybackEnabled {
    self.viewModel.fullscreenVideoPlaybackEnabled = browserFullscreenVideoPlaybackEnabled;
    self.preferencesStore.fullscreenVideoPlaybackEnabled = browserFullscreenVideoPlaybackEnabled;
}

- (void)browserPresentViewController:(UIViewController *)viewController {
    [self deactivateTopBarFocusMode];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)browserLoadHomePage {
    [self loadHomePage];
}

- (void)browserShowHints {
    [self showHintsAlert];
}

- (void)browserCreateNewTabLoadingHomePage:(BOOL)loadHomePage {
    [self.tabCoordinator createNewTabLoadingHomePage:loadHomePage];
}

- (void)browserUpdateTextFontSize {
    [self updateTextFontSize];
}

- (void)browserCaptureSnapshotForCurrentTab {
    [self.tabCoordinator captureSnapshotForCurrentTab];
}

- (void)browserRecreateActiveWebViewPreservingCurrentURL {
    [self.tabCoordinator recreateActiveWebViewPreservingCurrentURL];
}

- (void)browserBringCursorToFront {
    [self.view bringSubviewToFront:self.remoteInputController.cursorView];
}

- (void)browserPlayVideoUnderCursorIfAvailable {
    [self.videoPlaybackCoordinator playVideoUnderCursorIfAvailable];
}

#pragma mark - BrowserVideoPlaybackCoordinatorHost

- (BOOL)browserIsCursorModeEnabled {
    return self.remoteInputController.cursorModeEnabled;
}

- (CGPoint)browserDOMCursorPoint {
    return [self browserDOMPointForCursor];
}

- (UIViewController *)browserPresentedViewController {
    return self.presentedViewController;
}

- (NSString *)browserCurrentPageTitle {
    return self.webview.title;
}

#pragma mark - BrowserTabCoordinatorHost

- (void)browserTabCoordinatorPresentViewController:(UIViewController *)viewController {
    [self browserPresentViewController:viewController];
}

- (void)browserTabCoordinatorUpdateTextFontSize {
    [self updateTextFontSize];
}

- (void)browserTabCoordinatorDidChangeState {
    [self refreshBrowserChrome];
}

- (void)browserTabCoordinatorDidScrollByDeltaY:(CGFloat)deltaY
                                 contentOffsetY:(CGFloat)contentOffsetY {
    [self updateChromeAutoHideForScrollDeltaY:deltaY contentOffsetY:contentOffsetY];
}

- (BOOL)browserTabCoordinatorIsCursorModeEnabled {
    return self.remoteInputController.cursorModeEnabled;
}

#pragma mark - BrowserPageActionCoordinatorHost

- (BOOL)browserPageActionCoordinatorCreateNewTabWithRequest:(NSURLRequest *)request {
    return [self.tabCoordinator createNewTabWithRequest:request];
}

#pragma mark - BrowserRemoteInputControllerHost

- (UIScrollView *)browserRemoteInputControllerActiveScrollView {
    return [self isFavoritesHomeVisible]
        ? self.favoritesHomeViewController.scrollView
        : self.webview.scrollView;
}

- (UIViewController *)browserRemoteInputControllerPresentedViewController {
    return self.presentedViewController;
}

- (BOOL)browserRemoteInputControllerTopBarFocusActive {
    return self.topBarFocusActive;
}

- (BOOL)browserRemoteInputControllerCanActivateTopBarFocus {
    return [self canActivateTopBarFocusMode];
}

- (BOOL)browserRemoteInputControllerShouldExitTopBarForDownPress {
    return [self.chromeViewController shouldExitChromeForDownPress];
}

- (void)browserRemoteInputControllerActivateTopBarFocus {
    [self activateTopBarFocusMode];
}

- (void)browserRemoteInputControllerDeactivateTopBarFocus {
    [self deactivateTopBarFocusMode];
}

- (void)browserRemoteInputControllerHandlePrimaryAction {
    [self browserHandlePrimaryAction];
}

- (BOOL)browserRemoteInputControllerHandleLongSelectPress {
    if (!self.remoteInputController.cursorModeEnabled ||
        ![self isFavoritesHomeVisible] ||
        self.presentedViewController != nil) {
        return NO;
    }
    CGPoint cursorPoint = self.remoteInputController.cursorView.frame.origin;
    CGPoint homePoint =
        [self.favoritesHomeViewController.view convertPoint:cursorPoint fromView:self.view];
    return [self.favoritesHomeViewController handleLongPressAtPoint:homePoint];
}

- (void)browserRemoteInputControllerHandleTripleSelectPress {
    if ([self isFavoritesHomeVisible] || self.presentedViewController != nil) {
        return;
    }
    [self.remoteInputController setCursorModeEnabled:YES];
    [self setPageZoomed:!self.pageZoomed animated:YES];
}

- (void)browserRemoteInputControllerHandleMenuPress {
    UIViewController *presentedViewController = self.presentedViewController;
    if (presentedViewController != nil) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [self toggleBrowserChromeForMenuPress];
}

- (void)browserRemoteInputControllerHandlePlayPausePress {
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    if (alertController != nil) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self requestURLorSearchInput];
    }
}

- (void)browserRemoteInputControllerHandleAdvancedMenuPress {
    [self showAdvancedMenu];
}

- (NSString *)browserRemoteInputControllerHoverStateAtCursorPoint:(CGPoint)point {
    if (self.chromeViewController.isChromeVisible &&
        CGRectContainsPoint(self.chromeViewController.view.frame, point)) {
        [self.favoritesHomeViewController clearPointerHover];
        CGPoint chromePoint = [self.chromeViewController.view convertPoint:point fromView:self.view];
        return [self.chromeViewController containsInteractiveControlAtPoint:chromePoint]
            ? @"true"
            : @"false";
    }
    if ([self isFavoritesHomeVisible]) {
        CGPoint homePoint =
            [self.favoritesHomeViewController.view convertPoint:point fromView:self.view];
        [self.favoritesHomeViewController updatePointerHoverAtPoint:homePoint];
        return [self.favoritesHomeViewController containsInteractiveControlAtPoint:homePoint]
            ? @"true"
            : @"false";
    }
    [self.favoritesHomeViewController clearPointerHover];
    if (self.webview.request == nil) {
        return @"false";
    }
    CGPoint webPoint = [self.view convertPoint:point toView:self.webview];
    if (webPoint.y < 0) {
        return @"false";
    }
    CGPoint domPoint = [self browserDOMPointForCursor];
    return [self.pageActionCoordinator hoverStateAtDOMPoint:domPoint webView:self.webview];
}

- (CGPoint)browserRemoteInputControllerSnapPointForCursorPoint:(CGPoint)point {
    if (self.chromeViewController.isChromeVisible) {
        static CGFloat const kChromeMagnetCaptureRadius = 68.0;
        CGPoint chromePoint = [self.chromeViewController.view convertPoint:point fromView:self.view];
        CGPoint chromeMagnetPoint = CGPointZero;
        if ([self.chromeViewController getMagnetPoint:&chromeMagnetPoint
                                             forPoint:chromePoint
                                      maximumDistance:kChromeMagnetCaptureRadius]) {
            CGPoint targetPoint = [self.view convertPoint:chromeMagnetPoint
                                                 fromView:self.chromeViewController.view];
            return BrowserSmoothMagnetPoint(point,
                                            targetPoint,
                                            kChromeMagnetCaptureRadius);
        }
    }
    if ([self isFavoritesHomeVisible]) {
        CGPoint homePoint =
            [self.favoritesHomeViewController.view convertPoint:point fromView:self.view];
        CGPoint homeMagnetPoint = CGPointZero;
        if ([self.favoritesHomeViewController getMagnetPoint:&homeMagnetPoint
                                                    forPoint:homePoint
                                             maximumDistance:105.0]) {
            return [self.view convertPoint:homeMagnetPoint
                                  fromView:self.favoritesHomeViewController.view];
        }
    }
    return point;
}

- (void)browserRemoteInputControllerDidMoveCursorToPoint:(CGPoint)point {
    [self updatePageZoomForCursorPoint:point];
}

- (void)browserRemoteInputControllerDidScrollByDeltaY:(CGFloat)deltaY
                                        contentOffsetY:(CGFloat)contentOffsetY {
    [self updateChromeAutoHideForScrollDeltaY:deltaY contentOffsetY:contentOffsetY];
}

- (void)browserRemoteInputControllerSetWebInteractionEnabled:(BOOL)enabled {
    self.webview.userInteractionEnabled = enabled;
}

- (void)browserRemoteInputControllerPersistSession {
    [self.tabCoordinator persistSession];
}

#pragma mark - BrowserWebViewDelegate

- (BOOL)webView:(id)webView shouldCreateNewTabWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    (void)webView;
    (void)navigationType;
    return [self.tabCoordinator createNewTabWithRequest:request];
}

- (BOOL)webView:(id)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    (void)navigationType;
    [self.tabCoordinator prepareTabForRequest:request webView:webView];
    return YES;
}

- (void)webViewDidStartLoad:(id)webView {
    [self.tabCoordinator webViewDidStartLoad:webView];
}

- (void)webViewDidFinishLoad:(id)webView {
    [self.tabCoordinator webViewDidFinishLoad:webView];
}

- (void)webView:(id)webView didFailLoadWithError:(NSError *)error {
    BrowserTabViewModel *tab = [self.tabCoordinator tabForWebView:webView];
    if (tab == nil) {
        return;
    }
    [self.tabCoordinator webViewDidFailLoad:webView];

    NSURL *failingURL = error.userInfo[NSURLErrorFailingURLErrorKey];
    NSURLRequest *currentRequest = [webView request];
    NSString *currentRequestURLString = currentRequest.URL.absoluteString ?: @"";
    if (failingURL != nil &&
        currentRequestURLString.length > 0 &&
        ![failingURL.absoluteString isEqualToString:currentRequestURLString]) {
        return;
    }

    if (tab != self.tabCoordinator.activeTab) {
        return;
    }
    if ([self.navigationService shouldIgnoreLoadError:error]) {
        return;
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Could Not Load Webpage"
                                                                             message:error.localizedDescription
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    if (tab.requestURL.length > 1) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Google This Page"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(__unused UIAlertAction *action) {
            NSURLRequest *searchRequest = [weakSelf.navigationService googleSearchRequestForFailedRequestURLString:tab.requestURL];
            if (searchRequest != nil) {
                [weakSelf.webview loadRequest:searchRequest];
            }
        }]];
    }
    if (self.webview.request != nil && self.webview.request.URL.absoluteString.length > 0) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Reload Page"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(__unused UIAlertAction *action) {
            weakSelf.tabCoordinator.previousURL = @"";
            [weakSelf.webview reload];
        }]];
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Enter a URL or Search"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(__unused UIAlertAction *action) {
            [weakSelf requestURLorSearchInput];
        }]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:nil style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Presses / Touches

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self.remoteInputController handlePressesBegan:presses withEvent:event];
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if ([self.remoteInputController handlePressesEnded:presses withEvent:event]) {
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self.remoteInputController handlePressesCancelled:presses withEvent:event];
    [super pressesCancelled:presses withEvent:event];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ([self.remoteInputController handleTouchesBegan:touches withEvent:event]) {
        return;
    }
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ([self.remoteInputController handleTouchesMoved:touches withEvent:event]) {
        return;
    }
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)touches;
    (void)event;
    [self.remoteInputController handleTouchesEnded];
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    (void)touches;
    (void)event;
    [self.remoteInputController handleTouchesEnded];
    [super touchesCancelled:touches withEvent:event];
}

@end
