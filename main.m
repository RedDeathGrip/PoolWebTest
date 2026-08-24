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
      TOUCH FIX V4.1
      Fixes V4 menu bug:
      - DOES NOT globally block touch listeners.
      - Menus/buttons like "Play as Guest" remain normal.
      - Only touches that actually start on #engine are intercepted for aiming.
      - Separate right-side power bar remains.
    */

    NSString *touchFix =
    @"(() => {"
      "if (window.__POOL_TOUCH_FIX_V41__) return;"
      "window.__POOL_TOUCH_FIX_V41__ = true;"

      "const nativeAdd = EventTarget.prototype.addEventListener;"
      "const AIM_SENS = 0.20;"
      "const POWER_DRAG_PX = 300;"
      "const clamp = (v,lo,hi)=>Math.max(lo,Math.min(hi,v));"

      "let aimActive=false;"
      "let prevX=0,prevY=0,virtualX=0,virtualY=0;"

      "const getCanvas=()=>document.getElementById('engine');"
      "const isCanvasTarget=(t)=>{"
        "const c=getCanvas();"
        "return !!(c && t && (t===c || (c.contains && c.contains(t))));"
      "};"

      "const sendMouse=(type,x,y,buttons)=>{"
        "const c=getCanvas();"
        "if(!c)return;"
        "const r=c.getBoundingClientRect();"
        "const cx=clamp(x,r.left+2,r.right-2);"
        "const cy=clamp(y,r.top+2,r.bottom-2);"
        "c.dispatchEvent(new MouseEvent(type,{"
          "bubbles:true,cancelable:true,view:window,detail:1,"
          "clientX:cx,clientY:cy,screenX:cx,screenY:cy,button:0,buttons:buttons"
        "}));"
      "};"

      "const kill=e=>{e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();};"

      // EARLY capture listener: only intercept touches that begin on the game canvas.
      "nativeAdd.call(window,'touchstart',e=>{"
        "if(!e.changedTouches.length || !isCanvasTarget(e.target))return;"
        "kill(e);"
        "const t=e.changedTouches[0];"
        "aimActive=true;"
        "prevX=virtualX=t.clientX;"
        "prevY=virtualY=t.clientY;"
      "},{capture:true,passive:false});"

      "nativeAdd.call(window,'touchmove',e=>{"
        "if(!aimActive || !e.changedTouches.length)return;"
        "kill(e);"
        "const t=e.changedTouches[0];"
        "const dx=t.clientX-prevX, dy=t.clientY-prevY;"
        "prevX=t.clientX; prevY=t.clientY;"
        "const ox=virtualX, oy=virtualY;"
        "virtualX += dx*AIM_SENS;"
        "virtualY += dy*AIM_SENS;"
        "sendMouse('mousemove',ox+(virtualX-ox)*0.25,oy+(virtualY-oy)*0.25,0);"
        "sendMouse('mousemove',ox+(virtualX-ox)*0.50,oy+(virtualY-oy)*0.50,0);"
        "sendMouse('mousemove',ox+(virtualX-ox)*0.75,oy+(virtualY-oy)*0.75,0);"
        "sendMouse('mousemove',virtualX,virtualY,0);"
      "},{capture:true,passive:false});"

      "nativeAdd.call(window,'touchend',e=>{"
        "if(!aimActive)return;"
        "kill(e);"
        "aimActive=false;"
      "},{capture:true,passive:false});"

      "nativeAdd.call(window,'touchcancel',e=>{"
        "if(!aimActive)return;"
        "kill(e);"
        "aimActive=false;"
      "},{capture:true,passive:false});"

      "const installPower=()=>{"
        "const c=getCanvas();"
        "if(!c){setTimeout(installPower,150);return;}"
        "if(document.getElementById('pool-power-v41'))return;"

        "const p=document.createElement('div');"
        "p.id='pool-power-v41';"
        "p.innerHTML=`"
          "<div id='pool-power-label'>POWER</div>"
          "<div id='pool-power-track'><div id='pool-power-fill'></div><div id='pool-power-knob'></div></div>"
          "<div id='pool-power-pct'>0%</div>`;"

        "Object.assign(p.style,{"
          "position:'fixed',right:'10px',top:'50%',transform:'translateY(-50%)',"
          "width:'58px',height:'300px',zIndex:'2147483647',display:'flex',"
          "flexDirection:'column',alignItems:'center',justifyContent:'center',gap:'7px',"
          "fontFamily:'-apple-system,BlinkMacSystemFont,Arial,sans-serif',fontWeight:'700',"
          "color:'white',userSelect:'none',webkitUserSelect:'none',touchAction:'none',pointerEvents:'none'"
        "});"
        // Let the container ignore touches except for the actual slider track.
        "document.body.appendChild(p);"

        "const label=document.getElementById('pool-power-label');"
        "const track=document.getElementById('pool-power-track');"
        "const fill=document.getElementById('pool-power-fill');"
        "const knob=document.getElementById('pool-power-knob');"
        "const pct=document.getElementById('pool-power-pct');"

        "Object.assign(label.style,{fontSize:'10px',letterSpacing:'0.8px',textShadow:'0 1px 2px #000'});"
        "Object.assign(track.style,{"
          "position:'relative',width:'26px',height:'220px',borderRadius:'14px',"
          "background:'rgba(20,20,20,.72)',border:'2px solid rgba(255,255,255,.72)',"
          "overflow:'hidden',boxShadow:'0 1px 5px rgba(0,0,0,.55)',touchAction:'none',pointerEvents:'auto'"
        "});"
        "Object.assign(fill.style,{position:'absolute',left:'0',right:'0',top:'0',height:'0%',background:'rgba(255,255,255,.40)',pointerEvents:'none'});"
        "Object.assign(knob.style,{position:'absolute',left:'50%',top:'0%',width:'22px',height:'22px',borderRadius:'50%',background:'white',border:'2px solid rgba(0,0,0,.45)',transform:'translate(-50%,-2px)',boxSizing:'border-box',pointerEvents:'none'});"
        "Object.assign(pct.style,{fontSize:'10px',minWidth:'40px',textAlign:'center',textShadow:'0 1px 2px #000'});"

        "let active=false,anchorX=0,anchorY=0,current=0;"
        "const setVisual=v=>{v=clamp(v,0,1);current=v;fill.style.height=(v*100)+'%';knob.style.top=(v*100)+'%';pct.textContent=Math.round(v*100)+'%';};"
        "const fromTouch=t=>{const r=track.getBoundingClientRect();return clamp((t.clientY-r.top)/r.height,0,1);};"

        "nativeAdd.call(track,'touchstart',e=>{"
          "if(!e.changedTouches.length)return;kill(e);"
          "const t=e.changedTouches[0],r=c.getBoundingClientRect();"
          "anchorX=r.left+r.width*0.50;anchorY=r.top+r.height*0.48;"
          "active=true;const v=fromTouch(t);setVisual(v);"
          "sendMouse('mousedown',anchorX,anchorY,1);"
          "sendMouse('mousemove',anchorX,anchorY+v*POWER_DRAG_PX,1);"
        "},{capture:true,passive:false});"

        "nativeAdd.call(track,'touchmove',e=>{"
          "if(!active||!e.changedTouches.length)return;kill(e);"
          "const v=fromTouch(e.changedTouches[0]);setVisual(v);"
          "sendMouse('mousemove',anchorX,anchorY+v*POWER_DRAG_PX,1);"
        "},{capture:true,passive:false});"

        "nativeAdd.call(track,'touchend',e=>{"
          "if(!active)return;kill(e);"
          "sendMouse('mouseup',anchorX,anchorY+current*POWER_DRAG_PX,0);"
          "active=false;setTimeout(()=>setVisual(0),250);"
        "},{capture:true,passive:false});"

        "nativeAdd.call(track,'touchcancel',e=>{"
          "if(!active)return;kill(e);"
          "sendMouse('mouseup',anchorX,anchorY+current*POWER_DRAG_PX,0);"
          "active=false;setTimeout(()=>setVisual(0),250);"
        "},{capture:true,passive:false});"

        "setVisual(0);"
        "console.log('[TouchFixV4.1] power installed');"
      "};"

      "installPower();"
      "nativeAdd.call(document,'DOMContentLoaded',installPower,{once:true});"
      "new MutationObserver(installPower).observe(document.documentElement||document,{childList:true,subtree:true});"
      "console.log('[TouchFixV4.1] loaded');"
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

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(8,40,self.view.bounds.size.width-16,42)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.status.text = @"TOUCH FIX V4.1 • menu touch restored";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.76];
    self.status.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 9;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *url=[NSURL URLWithString:@"https://0wwafa.github.io/8ball/?utm_source=touchfixv41"];
    [self.web loadRequest:[NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:45]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.status.hidden=NO;
    self.status.text=@"TOUCH FIX V4.1 ACTIVE • menu works • table=aim • slider=power";
    [self.view bringSubviewToFront:self.status];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{ self.status.hidden=YES; });
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    self.status.hidden=NO;
    self.status.text=[NSString stringWithFormat:@"Load error: %@",error.localizedDescription];
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
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[VC new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc,char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass([AppDelegate class])); }
}
