
#import "DLGMemUI.h"
#import "DLGMemUIView.h"
#import "MEShortcutBar.h"

static UIWindow *activeApplicationWindow(void)
{
    UIApplication *application = UIApplication.sharedApplication;
    UIWindow *visibleWindow = nil;
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
            if (!visibleWindow && !window.hidden) {
                visibleWindow = window;
            }
        }
    }
    if (visibleWindow) {
        return visibleWindow;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *legacyWindow = application.keyWindow ?: application.windows.firstObject;
#pragma clang diagnostic pop
    return legacyWindow;
}

// The game can replace its key window after our first attach (splash to main window)
// or add views on top of the button, so check once a second and fix both cases.
static void keepButtonAttached(void)
{
    static NSTimer *timer = nil;
    if (timer) {
        return;
    }

    timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        DLGMemUIView *view = [DLGMemUIView instance];
        if (view.expanded) {
            return;
        }
        UIWindow *window = activeApplicationWindow();
        if (!window) {
            return;
        }
        if (view.superview != window) {
            NSLog(@"[memedit] re-attaching button to %@", NSStringFromClass(window.class));
            [window addSubview:view];
            [window setDLGMemUIView:view];
            [MEShortcutBar installInWindow:window];
        } else if (window.subviews.lastObject != view) {
            [window bringSubviewToFront:view];
        }
    }];
}

@implementation DLGMemUI

+ (void)addDLGMemUIView:(id<DLGMemUIViewDelegate>)delegate {
    UIApplication *application = [UIApplication sharedApplication];
    if (application) {
        UIWindow *window = activeApplicationWindow();
        if (window) {
            [DLGMemUI addDLGMemUIViewToWindow:window withDelegate:delegate];
            return;
        }
    }

    NSLog(@"[memedit] no window yet, retrying in 1s");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [DLGMemUI addDLGMemUIView:delegate];
    });
}

+ (void)addDLGMemUIViewToWindow:(UIWindow *)window withDelegate:(id<DLGMemUIViewDelegate>)delegate{
    CGRect frame = CGRectMake(0, 100, DLG_DEBUG_CONSOLE_VIEW_SIZE, DLG_DEBUG_CONSOLE_VIEW_SIZE);
    DLGMemUIView *view = [DLGMemUIView instance];
    view.delegate = delegate;
    view.translatesAutoresizingMaskIntoConstraints = YES;
    view.autoresizingMask = UIViewAutoresizingNone;
    view.frame = frame;
    view.alpha = 1.0f;
    [window addSubview:view];
    [window setDLGMemUIView:view];
    NSLog(@"[memedit] button added to %@ frame=%@ hidden=%d", NSStringFromClass(window.class), NSStringFromCGRect(view.frame), view.hidden);

    NSArray *gestures = view.gestureRecognizers;
    if (gestures == nil || gestures.count == 0) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:window action:@selector(handleGesture:)];
        [view addGestureRecognizer:pan];
    }

    if ([delegate respondsToSelector:@selector(DLGMemUILaunched:)]) {
        [delegate DLGMemUILaunched:view];
    }

    [MEShortcutBar installInWindow:window];
    keepButtonAttached();
}

+ (void)removeDLGMemUIView {
    DLGMemUIView *view = [DLGMemUIView instance];
    if (view.expanded) [view doCollapse];
    NSArray *gestures = view.gestureRecognizers;
    for (UIGestureRecognizer *gesture in gestures) {
        [view removeGestureRecognizer:gesture];
    }
    [view removeFromSuperview];
}

@end
