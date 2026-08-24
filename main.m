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
     TOUCH FIX V2
     - Blocks the game's/wrapper's competing touch listeners before they can attach.
     - Installs exactly one touch->mouse control layer using the ORIGINAL native addEventListener.
     - Aim sensitivity reduced to 0.50x.
     - One-finger drag = aim only.
     - Double-tap, hold second tap, drag = power.
     - Release = shoot.
    */
    NSString *touchFix =
    @"(() => {"
      "if (window.__POOL_TOUCH_FIX_V2__) return;"
      "window.__POOL_TOUCH_FIX_V2__ = true;"

      // Save browser-native listener registration BEFORE the page/game can replace it.
      "const nativeAdd = EventTarget.prototype.addEventListener;"
      "const nativeRemove = EventTarget.prototype.removeEventListener;"

      // Block competing touch handlers from the wrapper/game.
      // Our own handlers are installed later with nativeAdd.call(...), bypassing this blocker.
      "EventTarget.prototype.addEventListener = function(type, listener, options) {"
        "if (['touchstart','touchmove','touchend','touchcancel'].includes(type)) {"
          "return;"
        "}"
        "return nativeAdd.call(this, type, listener, options);"
      "};"

      "const install = () => {"
        "const canvas = document.getElementById('engine');"
        "if (!canvas) { setTimeout(install, 120); return; }"
        "if (canvas.dataset.touchFixV2 === '1') return;"
        "canvas.dataset.touchFixV2 = '1';"
        "canvas.style.touchAction = 'none';"

        "const AIM_SENS = 0.50;"
        "let lastTapTime = 0;"
        "let tapTimer = null;"
        "let startX = 0, startY = 0;"
        "let prevX = 0, prevY = 0;"
        "let virtualX = 0, virtualY = 0;"
        "let moved = false;"
        "let powerMode = false;"
        "let mouseHeld = false;"

        "const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));"

        "const mouseAt = (type, x, y, buttons) => {"
          "const r = canvas.getBoundingClientRect();"
          "const cx = clamp(x, r.left + 1, r.right - 1);"
          "const cy = clamp(y, r.top + 1, r.bottom - 1);"
          "const ev = new MouseEvent(type, {"
            "bubbles:true, cancelable:true, view:window, detail:1,"
            "screenX:cx, screenY:cy, clientX:cx, clientY:cy,"
            "button:0, buttons:buttons"
          "});"
          "canvas.dispatchEvent(ev);"
        "};"

        "const stop = e => {"
          "e.preventDefault();"
          "e.stopPropagation();"
          "e.stopImmediatePropagation();"
        "};"

        "const onStart = e => {"
          "if (!e.changedTouches.length) return;"
          "stop(e);"
          "const t = e.changedTouches[0];"
          "const now = Date.now();"
          "clearTimeout(tapTimer);"

          "startX = prevX = virtualX = t.clientX;"
          "startY = prevY = virtualY = t.clientY;"
          "moved = false;"

          "powerMode = ((now - lastTapTime) > 35 && (now - lastTapTime) < 330);"
          "lastTapTime = now;"

          "if (powerMode) {"
            "mouseAt('mousedown', virtualX, virtualY, 1);"
            "mouseHeld = true;"
          "}"
        "};"

        "const onMove = e => {"
          "if (!e.changedTouches.length) return;"
          "stop(e);"
          "const t = e.changedTouches[0];"
          "const dx = t.clientX - prevX;"
          "const dy = t.clientY - prevY;"
          "prevX = t.clientX;"
          "prevY = t.clientY;"

          "if (Math.hypot(t.clientX-startX, t.clientY-startY) > 5) moved = true;"
          "clearTimeout(tapTimer);"

          "if (powerMode) {"
            // Power uses direct 1:1 movement.
            "virtualX += dx;"
            "virtualY += dy;"
            "if (!mouseHeld) { mouseAt('mousedown', virtualX, virtualY, 1); mouseHeld = true; }"
            "mouseAt('mousemove', virtualX, virtualY, 1);"
          "} else {"
            // Aim uses reduced sensitivity.
            "virtualX += dx * AIM_SENS;"
            "virtualY += dy * AIM_SENS;"
            "mouseAt('mousemove', virtualX, virtualY, 0);"
          "}"
        "};"

        "const onEnd = e => {"
          "if (!e.changedTouches.length) return;"
          "stop(e);"
          "const t = e.changedTouches[0];"

          "if (mouseHeld) {"
            "mouseAt('mouseup', virtualX, virtualY, 0);"
            "mouseHeld = false;"
          "} else if (!moved && !powerMode) {"
            "const x = t.clientX, y = t.clientY;"
            // Slight delay allows the second tap to convert into power mode.
            "tapTimer = setTimeout(() => {"
              "mouseAt('mousedown', x, y, 1);"
              "mouseAt('mouseup', x, y, 0);"
              "mouseAt('click', x, y, 0);"
            "}, 220);"
          "}"

          "powerMode = false;"
        "};"

        "const onCancel = e => {"
          "if (!e.changedTouches.length) return;"
          "stop(e);"
          "if (mouseHeld) mouseAt('mouseup', virtualX, virtualY, 0);"
          "mouseHeld = false;"
          "powerMode = false;"
        "};"

        // Use the saved native method so our listeners cannot be blocked by the page.
        "nativeAdd.call(canvas, 'touchstart', onStart, {capture:true, passive:false});"
        "nativeAdd.call(canvas, 'touchmove', onMove, {capture:true, passive:false});"
        "nativeAdd.call(canvas, 'touchend', onEnd, {capture:true, passive:false});"
        "nativeAdd.call(canvas, 'touchcancel', onCancel, {capture:true, passive:false});"

        "console.log('[TouchFixV2] installed');"
      "};"

      // Install as early as possible and keep checking until the engine canvas exists.
      "install();"
      "nativeAdd.call(document, 'DOMContentLoaded', install, {once:true});"
      "const mo = new MutationObserver(install);"
      "mo.observe(document.documentElement || document, {childList:true, subtree:true});"
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
    self.status.text = @"TOUCH FIX V2 • clean aim controls • 0.50x sensitivity";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.76];
    self.status.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 9;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *url = [NSURL URLWithString:@"https://0wwafa.github.io/8ball/?utm_source=touchfixv2"];
    [self.web loadRequest:[NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:45]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.status.hidden = NO;
    self.status.text = @"TOUCH FIX V2 ACTIVE • drag=aim • double-tap+drag=power";
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
