#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>

@interface VC : UIViewController <WKNavigationDelegate>
@property(nonatomic,strong) WKWebView *web;
@property(nonatomic,strong) UILabel *status;
@end

@implementation VC

- (WKUserScript *)pageScript:(NSString *)source time:(WKUserScriptInjectionTime)time {
    if (@available(iOS 14.0, *)) {
        return [[WKUserScript alloc] initWithSource:source
                                     injectionTime:time
                                  forMainFrameOnly:YES
                                    inContentWorld:WKContentWorld.pageWorld];
    }
    return [[WKUserScript alloc] initWithSource:source
                                 injectionTime:time
                              forMainFrameOnly:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    cfg.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    cfg.allowsInlineMediaPlayback = YES;
    cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    /*
      TOUCH FIX V3

      Immediate finger drag  = AIM
      Hold ~0.28 sec + drag  = native POWER / cue pull
      Tap                    = normal native tap

      Important difference from V2:
      We DO NOT disable the game's native touch system globally.
      We only intercept touch MOVE events once we know the gesture is aiming.
      That lets the game's proven native cue-pull behavior handle power shots.

      Aim sensitivity: 0.20x
      Aim mousemoves are interpolated for smoother motion.
    */

    NSString *touchFix =
    @"(() => {"
      "if (window.__POOL_TOUCH_FIX_V3__) return;"
      "window.__POOL_TOUCH_FIX_V3__ = true;"

      "const AIM_SENS = 0.20;"
      "const POWER_HOLD_MS = 280;"
      "const MOVE_THRESHOLD = 4;"

      "let active = false;"
      "let mode = 'idle';" // idle | undecided | aim | power
      "let startX = 0, startY = 0;"
      "let prevX = 0, prevY = 0;"
      "let virtualX = 0, virtualY = 0;"
      "let holdTimer = null;"
      "let canvas = null;"

      "const getCanvas = () => document.getElementById('engine');"
      "const isGameTouch = e => {"
        "const c = getCanvas();"
        "if (!c || !e.target) return false;"
        "return e.target === c || (c.contains && c.contains(e.target));"
      "};"

      "const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));"

      "const sendMove = (x, y) => {"
        "canvas = getCanvas();"
        "if (!canvas) return;"
        "const r = canvas.getBoundingClientRect();"
        "const cx = clamp(x, r.left + 1, r.right - 1);"
        "const cy = clamp(y, r.top + 1, r.bottom - 1);"
        "canvas.dispatchEvent(new MouseEvent('mousemove', {"
          "bubbles:true, cancelable:true, view:window,"
          "clientX:cx, clientY:cy, screenX:cx, screenY:cy,"
          "button:0, buttons:0"
        "}));"
      "};"

      "const kill = e => {"
        "e.preventDefault();"
        "e.stopPropagation();"
        "e.stopImmediatePropagation();"
      "};"

      "window.addEventListener('touchstart', e => {"
        "if (!isGameTouch(e) || e.touches.length !== 1) return;"
        "const t = e.touches[0];"
        "active = true;"
        "mode = 'undecided';"
        "startX = prevX = virtualX = t.clientX;"
        "startY = prevY = virtualY = t.clientY;"

        "clearTimeout(holdTimer);"
        "holdTimer = setTimeout(() => {"
          "if (active && mode === 'undecided') {"
            "mode = 'power';"
            "console.log('[TouchFixV3] power mode');"
          "}"
        "}, POWER_HOLD_MS);"

        // DO NOT block touchstart.
        // The native game sees it, which is needed for reliable cue pull.
      "}, {capture:true, passive:false});"

      "window.addEventListener('touchmove', e => {"
        "if (!active || !isGameTouch(e) || e.touches.length < 1) return;"
        "const t = e.touches[0];"
        "const total = Math.hypot(t.clientX-startX, t.clientY-startY);"

        "if (mode === 'undecided' && total >= MOVE_THRESHOLD) {"
          "mode = 'aim';"
          "clearTimeout(holdTimer);"
          "console.log('[TouchFixV3] aim mode');"
        "}"

        "if (mode === 'power') {"
          // Let the REAL game touch handler receive the drag.
          // This is the behavior that successfully pulled the cue before.
          "return;"
        "}"

        "if (mode !== 'aim') return;"

        // AIM: block the native drag so it cannot pull the cue.
        "kill(e);"

        "const dx = t.clientX - prevX;"
        "const dy = t.clientY - prevY;"
        "prevX = t.clientX;"
        "prevY = t.clientY;"

        "const oldX = virtualX;"
        "const oldY = virtualY;"
        "virtualX += dx * AIM_SENS;"
        "virtualY += dy * AIM_SENS;"

        // Three short substeps = visibly smoother aim without extra lag.
        "sendMove(oldX + (virtualX-oldX)*0.34, oldY + (virtualY-oldY)*0.34);"
        "sendMove(oldX + (virtualX-oldX)*0.67, oldY + (virtualY-oldY)*0.67);"
        "sendMove(virtualX, virtualY);"
      "}, {capture:true, passive:false});"

      "window.addEventListener('touchend', e => {"
        "if (!active) return;"

        "clearTimeout(holdTimer);"

        "if (mode === 'aim') {"
          // Prevent the finished aim drag becoming a native shot/tap.
          "kill(e);"
        "}"
        // power + normal tap are allowed through to the native game.
        "active = false;"
        "mode = 'idle';"
      "}, {capture:true, passive:false});"

      "window.addEventListener('touchcancel', e => {"
        "clearTimeout(holdTimer);"
        "if (mode === 'aim') kill(e);"
        "active = false;"
        "mode = 'idle';"
      "}, {capture:true, passive:false});"

      "console.log('[TouchFixV3] loaded');"
    "})();";

    [cfg.userContentController addUserScript:[self pageScript:touchFix
                                                  time:WKUserScriptInjectionTimeAtDocumentStart]];

    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:cfg];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.scrollView.bounces = NO;
    self.web.scrollView.scrollEnabled = NO;
    self.web.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.web];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(8, 40, self.view.bounds.size.width-16, 42)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.status.text = @"TOUCH FIX V3 • drag=aim • hold then drag=power";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.76];
    self.status.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 9;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *url = [NSURL URLWithString:@"https://0wwafa.github.io/8ball/?utm_source=touchfixv3"];
    [self.web loadRequest:[NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:45]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.status.hidden = NO;
    self.status.text = @"TOUCH FIX V3 ACTIVE • drag=aim • HOLD then drag=power";
    [self.view bringSubviewToFront:self.status];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.status.hidden = YES;
    });
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    self.status.hidden = NO;
    self.status.text = [NSString stringWithFormat:@"Load error: %@", error.localizedDescription];
    [self.view bringSubviewToFront:self.status];
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [VC new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
