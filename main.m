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
      TOUCH FIX V4
      --------------------------------------------------
      TABLE:
        one-finger drag = AIM ONLY
        no native cue-pull touch behavior

      RIGHT-SIDE POWER BAR:
        touch/drag down = choose power
        release = shoot

      This goes back to V2's reliable approach:
      block competing touch handlers before the game attaches them,
      then install exactly one manual control layer.

      Aim sensitivity = 0.20x
    */

    NSString *touchFix =
    @"(() => {"
      "if (window.__POOL_TOUCH_FIX_V4__) return;"
      "window.__POOL_TOUCH_FIX_V4__ = true;"

      "const nativeAdd = EventTarget.prototype.addEventListener;"

      // Block the wrapper/game's own touch listeners. We add ours using nativeAdd.call().
      "EventTarget.prototype.addEventListener = function(type, listener, options) {"
        "if (['touchstart','touchmove','touchend','touchcancel'].includes(type)) return;"
        "return nativeAdd.call(this, type, listener, options);"
      "};"

      "const AIM_SENS = 0.20;"
      "const POWER_DRAG_PX = 300;"

      "const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));"

      "const install = () => {"
        "const canvas = document.getElementById('engine');"
        "if (!canvas) { setTimeout(install, 120); return; }"
        "if (document.getElementById('pool-power-v4')) return;"

        "canvas.style.touchAction = 'none';"

        // -------------------- AIM --------------------
        "let aimActive = false;"
        "let prevX = 0, prevY = 0;"
        "let virtualX = 0, virtualY = 0;"

        "const canvasRect = () => canvas.getBoundingClientRect();"

        "const sendMouse = (type, x, y, buttons) => {"
          "const r = canvasRect();"
          "const cx = clamp(x, r.left + 2, r.right - 2);"
          "const cy = clamp(y, r.top + 2, r.bottom - 2);"
          "canvas.dispatchEvent(new MouseEvent(type, {"
            "bubbles:true,"
            "cancelable:true,"
            "view:window,"
            "detail:1,"
            "clientX:cx,"
            "clientY:cy,"
            "screenX:cx,"
            "screenY:cy,"
            "button:0,"
            "buttons:buttons"
          "}));"
        "};"

        "const stop = e => {"
          "e.preventDefault();"
          "e.stopPropagation();"
          "e.stopImmediatePropagation();"
        "};"

        "const aimStart = e => {"
          "if (!e.changedTouches.length) return;"
          "stop(e);"
          "const t = e.changedTouches[0];"
          "aimActive = true;"
          "prevX = virtualX = t.clientX;"
          "prevY = virtualY = t.clientY;"
        "};"

        "const aimMove = e => {"
          "if (!aimActive || !e.changedTouches.length) return;"
          "stop(e);"
          "const t = e.changedTouches[0];"
          "const dx = t.clientX - prevX;"
          "const dy = t.clientY - prevY;"
          "prevX = t.clientX;"
          "prevY = t.clientY;"

          "const oldX = virtualX;"
          "const oldY = virtualY;"
          "virtualX += dx * AIM_SENS;"
          "virtualY += dy * AIM_SENS;"

          // smooth 4-step interpolation
          "sendMouse('mousemove', oldX + (virtualX-oldX)*0.25, oldY + (virtualY-oldY)*0.25, 0);"
          "sendMouse('mousemove', oldX + (virtualX-oldX)*0.50, oldY + (virtualY-oldY)*0.50, 0);"
          "sendMouse('mousemove', oldX + (virtualX-oldX)*0.75, oldY + (virtualY-oldY)*0.75, 0);"
          "sendMouse('mousemove', virtualX, virtualY, 0);"
        "};"

        "const aimEnd = e => {"
          "if (!aimActive) return;"
          "stop(e);"
          "aimActive = false;"
        "};"

        "nativeAdd.call(canvas, 'touchstart', aimStart, {capture:true, passive:false});"
        "nativeAdd.call(canvas, 'touchmove', aimMove, {capture:true, passive:false});"
        "nativeAdd.call(canvas, 'touchend', aimEnd, {capture:true, passive:false});"
        "nativeAdd.call(canvas, 'touchcancel', aimEnd, {capture:true, passive:false});"

        // -------------------- POWER UI --------------------
        "const power = document.createElement('div');"
        "power.id = 'pool-power-v4';"
        "power.innerHTML = `"
          "<div id='pool-power-label'>POWER</div>"
          "<div id='pool-power-track'>"
            "<div id='pool-power-fill'></div>"
            "<div id='pool-power-knob'></div>"
          "</div>"
          "<div id='pool-power-pct'>0%</div>`;"

        "Object.assign(power.style, {"
          "position:'fixed',"
          "right:'10px',"
          "top:'50%',"
          "transform:'translateY(-50%)',"
          "width:'58px',"
          "height:'300px',"
          "zIndex:'2147483647',"
          "display:'flex',"
          "flexDirection:'column',"
          "alignItems:'center',"
          "justifyContent:'center',"
          "gap:'7px',"
          "fontFamily:'-apple-system,BlinkMacSystemFont,Arial,sans-serif',"
          "fontWeight:'700',"
          "color:'white',"
          "userSelect:'none',"
          "webkitUserSelect:'none',"
          "touchAction:'none',"
          "pointerEvents:'auto'"
        "});"

        "document.body.appendChild(power);"

        "const label = document.getElementById('pool-power-label');"
        "const track = document.getElementById('pool-power-track');"
        "const fill = document.getElementById('pool-power-fill');"
        "const knob = document.getElementById('pool-power-knob');"
        "const pct = document.getElementById('pool-power-pct');"

        "Object.assign(label.style, {fontSize:'10px',letterSpacing:'0.8px',textShadow:'0 1px 2px #000'});"
        "Object.assign(track.style, {"
          "position:'relative',"
          "width:'26px',"
          "height:'220px',"
          "borderRadius:'14px',"
          "background:'rgba(20,20,20,0.72)',"
          "border:'2px solid rgba(255,255,255,0.72)',"
          "overflow:'hidden',"
          "boxShadow:'0 1px 5px rgba(0,0,0,.55)',"
          "touchAction:'none'"
        "});"
        "Object.assign(fill.style, {"
          "position:'absolute',"
          "left:'0',"
          "right:'0',"
          "top:'0',"
          "height:'0%',"
          "background:'rgba(255,255,255,0.40)',"
          "pointerEvents:'none'"
        "});"
        "Object.assign(knob.style, {"
          "position:'absolute',"
          "left:'50%',"
          "top:'0%',"
          "width:'22px',"
          "height:'22px',"
          "borderRadius:'50%',"
          "background:'white',"
          "border:'2px solid rgba(0,0,0,.45)',"
          "transform:'translate(-50%,-2px)',"
          "boxSizing:'border-box',"
          "pointerEvents:'none'"
        "});"
        "Object.assign(pct.style, {fontSize:'10px',minWidth:'40px',textAlign:'center',textShadow:'0 1px 2px #000'});"

        "let powerActive = false;"
        "let anchorX = 0, anchorY = 0;"
        "let currentPower = 0;"

        "const setPowerVisual = p => {"
          "p = clamp(p, 0, 1);"
          "currentPower = p;"
          "fill.style.height = (p*100) + '%';"
          "knob.style.top = (p*100) + '%';"
          "pct.textContent = Math.round(p*100) + '%';"
        "};"

        "const powerFromTouch = t => {"
          "const r = track.getBoundingClientRect();"
          "return clamp((t.clientY - r.top) / r.height, 0, 1);"
        "};"

        "const powerStart = e => {"
          "if (!e.changedTouches.length) return;"
          "stop(e);"
          "const t = e.changedTouches[0];"
          "const r = canvasRect();"

          // Fixed virtual mouse anchor near middle of the game canvas.
          // From here, dragging downward behaves like pulling the PC cue back.
          "anchorX = r.left + r.width * 0.50;"
          "anchorY = r.top + r.height * 0.48;"

          "powerActive = true;"
          "const p = powerFromTouch(t);"
          "setPowerVisual(p);"
          "sendMouse('mousedown', anchorX, anchorY, 1);"
          "sendMouse('mousemove', anchorX, anchorY + p * POWER_DRAG_PX, 1);"
        "};"

        "const powerMove = e => {"
          "if (!powerActive || !e.changedTouches.length) return;"
          "stop(e);"
          "const p = powerFromTouch(e.changedTouches[0]);"
          "setPowerVisual(p);"
          "sendMouse('mousemove', anchorX, anchorY + p * POWER_DRAG_PX, 1);"
        "};"

        "const powerEnd = e => {"
          "if (!powerActive) return;"
          "stop(e);"
          "sendMouse('mouseup', anchorX, anchorY + currentPower * POWER_DRAG_PX, 0);"
          "powerActive = false;"

          // reset the visual after the shot
          "setTimeout(() => setPowerVisual(0), 250);"
        "};"

        "nativeAdd.call(track, 'touchstart', powerStart, {capture:true, passive:false});"
        "nativeAdd.call(track, 'touchmove', powerMove, {capture:true, passive:false});"
        "nativeAdd.call(track, 'touchend', powerEnd, {capture:true, passive:false});"
        "nativeAdd.call(track, 'touchcancel', powerEnd, {capture:true, passive:false});"

        "setPowerVisual(0);"
        "console.log('[TouchFixV4] installed');"
      "};"

      "install();"
      "nativeAdd.call(document, 'DOMContentLoaded', install, {once:true});"
      "new MutationObserver(install).observe(document.documentElement || document, {childList:true, subtree:true});"
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
    self.status.text = @"TOUCH FIX V4 • table=aim • right bar=power";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.76];
    self.status.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 9;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *url = [NSURL URLWithString:@"https://0wwafa.github.io/8ball/?utm_source=touchfixv4"];
    [self.web loadRequest:[NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:45]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.status.hidden = NO;
    self.status.text = @"TOUCH FIX V4 ACTIVE • drag table=aim • right slider=power";
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
