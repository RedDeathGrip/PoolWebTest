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
     TOUCH FIX V1

     The public wrapper only installs its special mobile touch -> mouse handler when
     navigator.userAgentData.mobile is true. That test is unreliable on iPhone Safari/WKWebView.

     We install our own handler unconditionally once #engine exists.

     Controls:
       1-finger drag       = aim (mousemove, NO mouse button)
       single tap          = normal click
       double-tap + drag   = hold left mouse + drag (shot power)
       release             = mouseup / shoot
    */
    NSString *touchFix =
    @"(() => {"
      "if (window.__POOL_TOUCH_FIX_V1__) return;"
      "window.__POOL_TOUCH_FIX_V1__ = true;"

      "const install = () => {"
        "const canvas = document.getElementById('engine');"
        "if (!canvas) { setTimeout(install, 250); return; }"
        "if (canvas.dataset.touchFixV1 === '1') return;"
        "canvas.dataset.touchFixV1 = '1';"
        "canvas.style.touchAction = 'none';"

        "let lastTapTime = 0;"
        "let tapTimer = null;"
        "let startX = 0, startY = 0;"
        "let moved = false;"
        "let powerMode = false;"
        "let mouseHeld = false;"

        "const sendMouse = (type, touch, buttons) => {"
          "const ev = new MouseEvent(type, {"
            "bubbles: true,"
            "cancelable: true,"
            "view: window,"
            "detail: 1,"
            "screenX: touch.screenX,"
            "screenY: touch.screenY,"
            "clientX: touch.clientX,"
            "clientY: touch.clientY,"
            "button: 0,"
            "buttons: buttons"
          "});"
          "canvas.dispatchEvent(ev);"
        "};"

        "const killTouch = (e) => {"
          "e.preventDefault();"
          "e.stopPropagation();"
          "e.stopImmediatePropagation();"
        "};"

        "canvas.addEventListener('touchstart', e => {"
          "if (!e.changedTouches.length) return;"
          "killTouch(e);"
          "const t = e.changedTouches[0];"
          "const now = Date.now();"
          "startX = t.clientX;"
          "startY = t.clientY;"
          "moved = false;"
          "clearTimeout(tapTimer);"

          "const isDouble = (now - lastTapTime) > 0 && (now - lastTapTime) < 320;"
          "powerMode = isDouble;"

          "if (powerMode) {"
            "sendMouse('mousedown', t, 1);"
            "mouseHeld = true;"
          "}"
          "lastTapTime = now;"
        "}, {capture:true, passive:false});"

        "canvas.addEventListener('touchmove', e => {"
          "if (!e.changedTouches.length) return;"
          "killTouch(e);"
          "const t = e.changedTouches[0];"
          "if (Math.hypot(t.clientX-startX, t.clientY-startY) > 4) moved = true;"
          "clearTimeout(tapTimer);"

          "if (powerMode) {"
            "if (!mouseHeld) { sendMouse('mousedown', t, 1); mouseHeld = true; }"
            "sendMouse('mousemove', t, 1);"
          "} else {"
            "// AIM ONLY: move the PC mouse with NO mouse button held."
            "sendMouse('mousemove', t, 0);"
          "}"
        "}, {capture:true, passive:false});"

        "canvas.addEventListener('touchend', e => {"
          "if (!e.changedTouches.length) return;"
          "killTouch(e);"
          "const t = e.changedTouches[0];"

          "if (mouseHeld) {"
            "sendMouse('mouseup', t, 0);"
            "mouseHeld = false;"
          "} else if (!moved && !powerMode) {"
            "// Delay slightly so a possible second tap can turn this into power mode."
            "const saved = {screenX:t.screenX,screenY:t.screenY,clientX:t.clientX,clientY:t.clientY};"
            "tapTimer = setTimeout(() => {"
              "const fake = saved;"
              "sendMouse('mousedown', fake, 1);"
              "sendMouse('mouseup', fake, 0);"
              "sendMouse('click', fake, 0);"
            "}, 180);"
          "}"
          "powerMode = false;"
        "}, {capture:true, passive:false});"

        "canvas.addEventListener('touchcancel', e => {"
          "if (!e.changedTouches.length) return;"
          "killTouch(e);"
          "const t = e.changedTouches[0];"
          "if (mouseHeld) sendMouse('mouseup', t, 0);"
          "mouseHeld = false;"
          "powerMode = false;"
        "}, {capture:true, passive:false});"

        "console.log('[TouchFixV1] installed');"
      "};"

      "if (document.readyState === 'loading') {"
        "document.addEventListener('DOMContentLoaded', install, {once:true});"
      "} else { install(); }"
      "new MutationObserver(install).observe(document.documentElement || document, {childList:true, subtree:true});"
    "})();";

    [cfg.userContentController addUserScript:[self pageScript:touchFix time:WKUserScriptInjectionTimeAtDocumentStart]];

    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:cfg];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.scrollView.bounces = NO;
    self.web.scrollView.scrollEnabled = NO;
    self.web.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.web];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(8, 40, self.view.bounds.size.width-16, 42)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.status.text = @"TOUCH FIX V1 • 1 finger=aim • double-tap+drag=power";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
    self.status.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 9;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    // This is the wrapper that already proved the real game engine runs on the iPhone.
    NSURL *url = [NSURL URLWithString:@"https://0wwafa.github.io/8ball/?utm_source=touchfixv1"];
    [self.web loadRequest:[NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:45]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.status.text = @"TOUCH FIX V1 ACTIVE • drag=aim • double-tap+drag=power";
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
