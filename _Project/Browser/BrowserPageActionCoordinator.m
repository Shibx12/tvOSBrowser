#import "BrowserPageActionCoordinator.h"

#import "BrowserDOMInteractionService.h"
#import "BrowserNavigationService.h"
#import "BrowserVideoPlaybackCoordinator.h"
#import "BrowserWebView.h"

@interface BrowserPageActionCoordinator ()

@property (nonatomic, weak) id<BrowserPageActionCoordinatorHost> host;
@property (nonatomic) BrowserDOMInteractionService *domInteractionService;
@property (nonatomic) BrowserNavigationService *navigationService;
@property (nonatomic) BrowserVideoPlaybackCoordinator *videoPlaybackCoordinator;
@property (nonatomic) UITextField *activeEditableTextField;
@property (nonatomic, weak) BrowserWebView *activeEditableWebView;
@property (nonatomic) CGPoint activeEditablePoint;

@end

@implementation BrowserPageActionCoordinator

- (instancetype)initWithHost:(id<BrowserPageActionCoordinatorHost>)host
       domInteractionService:(BrowserDOMInteractionService *)domInteractionService
           navigationService:(BrowserNavigationService *)navigationService
    videoPlaybackCoordinator:(BrowserVideoPlaybackCoordinator *)videoPlaybackCoordinator {
    self = [super init];
    if (self) {
        _host = host;
        _domInteractionService = domInteractionService;
        _navigationService = navigationService;
        _videoPlaybackCoordinator = videoPlaybackCoordinator;
    }
    return self;
}

- (NSString *)hoverStateAtDOMPoint:(CGPoint)point webView:(BrowserWebView *)webView {
    return [self.domInteractionService evaluateHoverStateJavaScriptAtPoint:point webView:webView];
}

- (BOOL)handleTargetBlankLinkAtDOMPoint:(CGPoint)point webView:(BrowserWebView *)webView {
    NSDictionary *linkInfo = [self.domInteractionService linkInfoAtDOMPoint:point webView:webView];
    NSString *href = [linkInfo[@"href"] isKindOfClass:[NSString class]] ? linkInfo[@"href"] : @"";
    NSString *target = [linkInfo[@"target"] isKindOfClass:[NSString class]] ? linkInfo[@"target"] : @"";

    if (href.length == 0 || ![target isEqualToString:@"_blank"]) {
        return NO;
    }

    NSURLRequest *request = [self.navigationService requestForURLString:href];
    if (request == nil) {
        return NO;
    }

    return [self.host browserPageActionCoordinatorCreateNewTabWithRequest:request];
}

- (void)commitEditableText:(NSString *)text
                   atPoint:(CGPoint)point
                   webView:(BrowserWebView *)webView {
    if (webView == nil) {
        return;
    }

    NSString *escapedText = [self.domInteractionService javaScriptEscapedString:text ?: @""];
    [self.domInteractionService evaluateEditableElementJavaScriptAtPoint:point
                                                                 webView:webView
                                                                    body:[NSString stringWithFormat:@"var target = browserEditableTarget();"
                                                                          "if (!target) { return 'false'; }"
                                                                          "if (typeof target.value !== 'undefined') { target.value = '%@'; }"
                                                                          "else { target.textContent = '%@'; }"
                                                                          "if (target.dispatchEvent) {"
                                                                              "var eventWindow = (target.ownerDocument && target.ownerDocument.defaultView) || window;"
                                                                              "target.dispatchEvent(new eventWindow.Event('input', { bubbles: true }));"
                                                                              "target.dispatchEvent(new eventWindow.Event('change', { bubbles: true }));"
                                                                          "}"
                                                                          "return 'true';", escapedText, escapedText]];
}

- (void)clearEditablePromptContext {
    [self.activeEditableTextField resignFirstResponder];
    [self.activeEditableTextField removeFromSuperview];
    self.activeEditableTextField = nil;
    self.activeEditableWebView = nil;
    self.activeEditablePoint = CGPointZero;
}

- (void)editableTextFieldDidFinish:(UITextField *)textField {
    BrowserWebView *webView = self.activeEditableWebView;
    CGPoint point = self.activeEditablePoint;
    if (textField != self.activeEditableTextField || webView == nil) {
        return;
    }

    [self commitEditableText:textField.text atPoint:point webView:webView];
    [self clearEditablePromptContext];
}

- (void)presentEditableFieldPromptForFieldType:(NSString *)fieldType
                                         point:(CGPoint)point
                                       webView:(BrowserWebView *)webView {
    [self clearEditablePromptContext];

    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(-100.0, -100.0, 1.0, 1.0)];
    if ([fieldType isEqualToString:@"url"]) {
        textField.keyboardType = UIKeyboardTypeURL;
    } else if ([fieldType isEqualToString:@"email"]) {
        textField.keyboardType = UIKeyboardTypeEmailAddress;
    } else if ([fieldType isEqualToString:@"tel"] ||
               [fieldType isEqualToString:@"number"] ||
               [fieldType isEqualToString:@"date"] ||
               [fieldType isEqualToString:@"datetime"] ||
               [fieldType isEqualToString:@"datetime-local"]) {
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    } else {
        textField.keyboardType = UIKeyboardTypeDefault;
    }
    textField.secureTextEntry = [fieldType isEqualToString:@"password"];
    textField.text = [self.domInteractionService evaluateEditableElementJavaScriptAtPoint:point
                                                                                  webView:webView
                                                                                     body:@"var target = browserEditableTarget();"
                                                                                          "if (!target) { return ''; }"
                                                                                          "if (typeof target.value !== 'undefined') { return target.value; }"
                                                                                          "return target.textContent || '';"];
    textField.returnKeyType = UIReturnKeyDone;
    textField.backgroundColor = UIColor.clearColor;
    textField.borderStyle = UITextBorderStyleNone;
    textField.alpha = 0.01;
    textField.accessibilityElementsHidden = YES;
    [textField addTarget:self
                  action:@selector(editableTextFieldDidFinish:)
        forControlEvents:UIControlEventEditingDidEndOnExit];

    self.activeEditableTextField = textField;
    self.activeEditableWebView = webView;
    self.activeEditablePoint = point;
    UIView *keyboardHostView = webView.superview ?: webView;
    [keyboardHostView addSubview:textField];
    [textField becomeFirstResponder];
}

- (BOOL)handlePageSelectionAtDOMPoint:(CGPoint)point webView:(BrowserWebView *)webView {
    if ([self handleTargetBlankLinkAtDOMPoint:point webView:webView]) {
        return YES;
    }

    NSString *frameClickResult =
        [self.domInteractionService evaluateResolvedElementJavaScriptAtPoint:point
                                                                     webView:webView
                                                                        body:@"if (resolvedElement && resolvedElement.tagName &&"
                                                                             "resolvedElement.tagName.toLowerCase() === 'iframe' &&"
                                                                             "typeof window.__browserFrameClickAtPoint === 'function') {"
                                                                                 "return window.__browserFrameClickAtPoint(resolvedClientX, resolvedClientY) ? 'true' : 'false';"
                                                                             "}"
                                                                             "return 'false';"];
    if ([frameClickResult isEqualToString:@"true"]) {
        return YES;
    }

    NSString *hasWebControl = [self.domInteractionService evaluateResolvedElementJavaScriptAtPoint:point
                                                                                           webView:webView
                                                                                              body:@"function browserLooksLikePageControl(element) {"
                                                                                                   "var candidate = element;"
                                                                                                   "var depth = 0;"
                                                                                                   "while (candidate && depth < 12) {"
                                                                                                       "var text = (candidate.textContent || '').replace(/\\s+/g, ' ').trim();"
                                                                                                       "var shortText = text.length <= 20 ? text : '';"
                                                                                                       "var value = ["
                                                                                                           "candidate.id || '',"
                                                                                                           "candidate.className || '',"
                                                                                                           "candidate.getAttribute ? (candidate.getAttribute('aria-label') || '') : '',"
                                                                                                           "candidate.getAttribute ? (candidate.getAttribute('title') || '') : '',"
                                                                                                           "candidate.getAttribute ? (candidate.getAttribute('data-tooltip') || '') : '',"
                                                                                                           "shortText"
                                                                                                       "].join(' ').toLowerCase();"
                                                                                                       "if ((/(^|[^a-z])(close|dismiss|cancel|mute|unmute|volume|sound|audio|pause|captions?|subtitles?|settings|quality|fullscreen|full-screen|pip)([^a-z]|$)/).test(value) ||"
                                                                                                           "value.indexOf('picture-in-picture') !== -1 ||"
                                                                                                           "value.indexOf('icon-close') !== -1 ||"
                                                                                                           "value.indexOf('modal-close') !== -1) {"
                                                                                                           "return true;"
                                                                                                       "}"
                                                                                                       "candidate = browserParentElement(candidate);"
                                                                                                       "depth += 1;"
                                                                                                   "}"
                                                                                                   "return false;"
                                                                                               "}"
                                                                                               "return (interactiveElement || browserLooksLikePageControl(resolvedElement)) ? 'true' : 'false';"];
    if (![hasWebControl isEqualToString:@"true"] &&
        [self.videoPlaybackCoordinator handleSelectPressForVideoAtCursor]) {
        return YES;
    }

    NSString *fieldType = [self.domInteractionService evaluateResolvedElementJavaScriptAtPoint:point
                                                                                        webView:webView
                                                                                           body:@"function browserEditableTargetAtPoint() {"
                                                                                                "var candidate = editableElement;"
                                                                                                "if (!candidate && resolvedElement && resolvedElement.matches) {"
                                                                                                    "if (resolvedElement.matches(editableSelector) || resolvedElement.matches('textarea, select')) {"
                                                                                                        "candidate = resolvedElement;"
                                                                                                    "}"
                                                                                                "}"
                                                                                                "if (!candidate) { return null; }"
                                                                                                "window.__browserLastEditableElement = candidate;"
                                                                                                "return candidate;"
                                                                                                "}"
                                                                                                "var target = browserEditableTargetAtPoint();"
                                                                                                "if (!target) { return ''; }"
                                                                                                "var tagName = target.tagName ? target.tagName.toLowerCase() : '';"
                                                                                                "var type = (target.type || '').toLowerCase();"
                                                                                                "if (tagName === 'textarea' || target.isContentEditable) { return 'text'; }"
                                                                                                "if (tagName === 'input' && !type) { return 'text'; }"
                                                                                                "return type;"];
    [self.domInteractionService evaluateResolvedElementJavaScriptAtPoint:point
                                                                 webView:webView
                                                                    body:@"function browserLooksLikeCloseControl(element) {"
                                                                         "if (!element) { return false; }"
                                                                         "var text = (element.textContent || '').replace(/\\s+/g, ' ').trim();"
                                                                         "var shortText = text.length <= 4 ? text : '';"
                                                                         "var value = ["
                                                                             "element.id || '',"
                                                                             "element.className || '',"
                                                                             "element.getAttribute ? (element.getAttribute('aria-label') || '') : '',"
                                                                             "element.getAttribute ? (element.getAttribute('title') || '') : '',"
                                                                             "element.getAttribute ? (element.getAttribute('data-dismiss') || '') : '',"
                                                                             "element.getAttribute ? (element.getAttribute('data-action') || '') : '',"
                                                                             "shortText"
                                                                         "].join(' ').toLowerCase();"
                                                                         "var matched = (/(^|[^a-z])(close|dismiss|cancel|exit)([^a-z]|$)/).test(value) ||"
                                                                             "value.indexOf('modal-close') !== -1 ||"
                                                                             "value.indexOf('popup-close') !== -1 ||"
                                                                             "value.indexOf('icon-close') !== -1 ||"
                                                                             "shortText === '×' || shortText === '✕' || shortText === '✖' || shortText === 'x' || shortText === 'X';"
                                                                         "if (!matched) { return false; }"
                                                                         "if (shortText === '×' || shortText === '✕' || shortText === '✖' || shortText === 'x' || shortText === 'X') { return true; }"
                                                                         "var buttonLike = element.matches && element.matches('button,a,[role=\"button\"],[onclick],[tabindex]');"
                                                                         "if (buttonLike) { return true; }"
                                                                         "try {"
                                                                             "var rect = element.getBoundingClientRect();"
                                                                             "return rect.width > 0 && rect.height > 0 && rect.width <= 160 && rect.height <= 160;"
                                                                         "} catch (error) { return false; }"
                                                                     "}"
                                                                     "function browserCloseAncestor(element) {"
                                                                         "var candidate = element;"
                                                                         "var depth = 0;"
                                                                         "while (candidate && depth < 16) {"
                                                                             "if (browserLooksLikeCloseControl(candidate)) { return candidate; }"
                                                                             "candidate = browserParentElement(candidate);"
                                                                             "depth += 1;"
                                                                         "}"
                                                                         "return null;"
                                                                     "}"
                                                                     "var closeTarget = browserCloseAncestor(resolvedElement);"
                                                                     "var hitTarget = closeTarget || resolvedElement;"
                                                                     "var actionTarget = closeTarget || editableElement || interactiveElement || hitTarget;"
                                                                         "if (!hitTarget || !actionTarget) { return 'false'; }"
                                                                         "try { if (actionTarget.focus) { actionTarget.focus({ preventScroll: true }); } } catch (error) {"
                                                                             "try { if (actionTarget.focus) { actionTarget.focus(); } } catch (ignoredError) {}"
                                                                         "}"
                                                                         "function dispatchPointerLikeEvent(target, type, constructorName, buttons, bubbles) {"
                                                                             "var ownerDocument = target.ownerDocument || resolvedDocument || document;"
                                                                             "var ownerWindow = ownerDocument.defaultView || resolvedWindow || window;"
                                                                             "try {"
                                                                                 "var Constructor = ownerWindow[constructorName];"
                                                                                 "if (Constructor) {"
                                                                                     "var options = { bubbles: bubbles, cancelable: true, composed: true, view: ownerWindow, detail: 1, clientX: resolvedClientX, clientY: resolvedClientY, screenX: resolvedClientX, screenY: resolvedClientY, button: 0, buttons: buttons };"
                                                                                     "if (constructorName === 'PointerEvent') {"
                                                                                         "options.pointerId = 1;"
                                                                                         "options.pointerType = 'mouse';"
                                                                                         "options.isPrimary = true;"
                                                                                         "options.width = 1;"
                                                                                         "options.height = 1;"
                                                                                         "options.pressure = buttons ? 0.5 : 0;"
                                                                                     "}"
                                                                                     "var event = new Constructor(type, options);"
                                                                                     "return target.dispatchEvent(event);"
                                                                                 "}"
                                                                             "} catch (error) {}"
                                                                             "var mouseEvent = ownerDocument.createEvent('MouseEvents');"
                                                                             "mouseEvent.initMouseEvent(type, bubbles, true, ownerWindow, 1, resolvedClientX, resolvedClientY, resolvedClientX, resolvedClientY, false, false, false, false, 0, null);"
                                                                             "return target.dispatchEvent(mouseEvent);"
                                                                         "}"
                                                                         "function dispatchTouchEvent(target, type) {"
                                                                             "try {"
                                                                                 "var ownerDocument = target.ownerDocument || resolvedDocument || document;"
                                                                                 "var ownerWindow = ownerDocument.defaultView || resolvedWindow || window;"
                                                                                 "if (!ownerWindow.Touch || !ownerWindow.TouchEvent) { return; }"
                                                                                 "var touch = new ownerWindow.Touch({ identifier: 1, target: target, clientX: resolvedClientX, clientY: resolvedClientY, screenX: resolvedClientX, screenY: resolvedClientY, pageX: resolvedClientX + ownerWindow.scrollX, pageY: resolvedClientY + ownerWindow.scrollY, radiusX: 1, radiusY: 1, force: type === 'touchstart' ? 0.5 : 0 });"
                                                                                 "var activeTouches = type === 'touchstart' ? [touch] : [];"
                                                                                 "target.dispatchEvent(new ownerWindow.TouchEvent(type, { bubbles: true, cancelable: true, composed: true, touches: activeTouches, targetTouches: activeTouches, changedTouches: [touch] }));"
                                                                             "} catch (error) {}"
                                                                         "}"
                                                                         "if (closeTarget) { dispatchTouchEvent(hitTarget, 'touchstart'); }"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'pointerover', 'PointerEvent', 0, true);"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'mouseover', 'MouseEvent', 0, true);"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'pointerenter', 'PointerEvent', 0, false);"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'mouseenter', 'MouseEvent', 0, false);"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'pointerdown', 'PointerEvent', 1, true);"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'mousedown', 'MouseEvent', 1, true);"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'pointerup', 'PointerEvent', 0, true);"
                                                                         "dispatchPointerLikeEvent(hitTarget, 'mouseup', 'MouseEvent', 0, true);"
                                                                         "if (closeTarget) { dispatchTouchEvent(hitTarget, 'touchend'); }"
                                                                         "if (typeof actionTarget.click === 'function') { actionTarget.click(); }"
                                                                         "else { dispatchPointerLikeEvent(hitTarget, 'click', 'MouseEvent', 0, true); }"
                                                                         "return 'true';"];
    fieldType = fieldType.lowercaseString;
    if ([fieldType isEqualToString:@"date"] ||
        [fieldType isEqualToString:@"datetime"] ||
        [fieldType isEqualToString:@"datetime-local"] ||
        [fieldType isEqualToString:@"email"] ||
        [fieldType isEqualToString:@"month"] ||
        [fieldType isEqualToString:@"number"] ||
        [fieldType isEqualToString:@"password"] ||
        [fieldType isEqualToString:@"search"] ||
        [fieldType isEqualToString:@"tel"] ||
        [fieldType isEqualToString:@"text"] ||
        [fieldType isEqualToString:@"time"] ||
        [fieldType isEqualToString:@"url"] ||
        [fieldType isEqualToString:@"week"]) {
        [self presentEditableFieldPromptForFieldType:fieldType point:point webView:webView];
    }
    return YES;
}

@end
