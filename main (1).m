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
      TOUCH FIX V4.2

      WHAT CHANGED FROM V4.1, AND WHY:

      1) MENU / BUTTON TAPS BROKEN
         The whole game (menu, buttons, table) is drawn on ONE canvas
         (#engine). There is no separate DOM element per button, so we
         can't tell "tap on Play as Guest" from "drag on the table" by
         looking at e.target — they're the same element. V4.1 always
         killed canvas touches, so buttons never got a native tap.
         FIX: we no longer decide at touchstart. We wait to see if the
         finger actually moves past a small threshold. If it stays put
         (a tap), we synthesize mousedown+mouseup+click at that point —
         the game is fundamentally a mouse-driven web game, so it
         already expects clicks to arrive this way (same as how our
         aim/power code already drives it with synthetic MouseEvents).
         If it moves past the threshold, we treat it as a drag (aim).

      2) AIM NOT UNDER THE FINGER
         V4.1 tracked *relative delta* movement scaled by 0.20, so the
         virtual aim point drifted away from the real finger position
         over time. FIX: aim is now ABSOLUTE — we send the finger's
         actual clientX/clientY straight through, 1:1, every move.

      3) POWER SLIDER GLITCHING / SOMETIMES NOT WORKING
         V4.1's window-level touchmove/touchend listeners only checked
         a boolean `aimActive` flag, not which finger. If you touched
         the power slider with a second finger while the first was
         still down on the table, the aim listener could steal (and
         kill) that second touch's events before the slider's own
         listener ever saw them. FIX: every touch is now tracked by
         its `identifier`. The aim listeners only ever act on the one
         touch that started on the canvas; any other simultaneous
         touch (e.g. on the power slider) is left completely alone.

      Power slider mechanics themselves are unchanged from V4.1.
    */

    NSString *touchFix =
    @"(() => {"
      "if (window.__POOL_TOUCH_FIX_V42__) return;"
      "window.__POOL_TOUCH_FIX_V42__ = true;"

      "const nativeAdd = EventTarget.prototype.addEventListener;"
      "const POWER_DRAG_PX = 300;"
      "const TAP_MAX_MOVE = 12;"   // px — below this, a lift counts as a tap not a drag
      "const TAP_MAX_TIME = 350;"  // ms — above this, even a still touch is not a tap
      "const clamp = (v,lo,hi)=>Math.max(lo,Math.min(hi,v));"

      "const getCanvas=()=>document.getElementById('engine');"
      "const isCanvasTarget=(t)=>{"
        "const c=getCanvas();"
        "return !!(c && t && (t===c || (c.contains && c.contains(t))));"
      "};"
      "const findTouch=(list,id)=>{"
        "for (let i=0;i<list.length;i++) if (list[i].identifier===id) return list[i];"
        "return null;"
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

      "const synthClick=(x,y)=>{"
        "const c=getCanvas();"
        "if(!c)return;"
        "const r=c.getBoundingClientRect();"
        "const cx=clamp(x,r.left+2,r.right-2);"
        "const cy=clamp(y,r.top+2,r.bottom-2);"
        "const base={bubbles:true,cancelable:true,view:window,detail:1,clientX:cx,clientY:cy,screenX:cx,screenY:cy,button:0};"
        "c.dispatchEvent(new MouseEvent('mousedown',Object.assign({},base,{buttons:1})));"
        "c.dispatchEvent(new MouseEvent('mouseup',Object.assign({},base,{buttons:0})));"
        "c.dispatchEvent(new MouseEvent('click',Object.assign({},base,{buttons:0})));"
      "};"

      "const kill=e=>{e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();};"

      // -------------------- AIM / TAP (single touch, identifier-tracked) --------------------
      "let aimTouchId=null, aimDragging=false, aimStartX=0, aimStartY=0, aimStartTime=0;"

      "nativeAdd.call(window,'touchstart',e=>{"
        "if(!e.changedTouches.length || aimTouchId!==null) return;"
        "const t=e.changedTouches[0];"
        "if(!isCanvasTarget(e.target)) return;"
        "kill(e);"
        "aimTouchId=t.identifier;"
        "aimDragging=false;"
        "aimStartX=t.clientX; aimStartY=t.clientY;"
        "aimStartTime=Date.now();"
      "},{capture:true,passive:false});"

      "nativeAdd.call(window,'touchmove',e=>{"
        "if(aimTouchId===null) return;"
        "const t=findTouch(e.changedTouches,aimTouchId);"
        "if(!t) return;"
        "kill(e);"
        "const dx=t.clientX-aimStartX, dy=t.clientY-aimStartY;"
        "if(!aimDragging && Math.hypot(dx,dy)>TAP_MAX_MOVE){ aimDragging=true; }"
        "if(aimDragging){ sendMouse('mousemove',t.clientX,t.clientY,0); }"
      "},{capture:true,passive:false});"

      "nativeAdd.call(window,'touchend',e=>{"
        "if(aimTouchId===null) return;"
        "const t=findTouch(e.changedTouches,aimTouchId);"
        "if(!t) return;"
        "kill(e);"
        "const dt=Date.now()-aimStartTime;"
        "if(!aimDragging && dt<TAP_MAX_TIME){ synthClick(t.clientX,t.clientY); }"
        "aimTouchId=null; aimDragging=false;"
      "},{capture:true,passive:false});"

      "nativeAdd.call(window,'touchcancel',e=>{"
        "if(aimTouchId===null) return;"
        "const t=findTouch(e.changedTouches,aimTouchId);"
        "if(t) kill(e);"
        "aimTouchId=null; aimDragging=false;"
      "},{capture:true,passive:false});"

      // -------------------- POWER UI (unchanged mechanics from V4.1) --------------------
      "const installPower=()=>{"
        "const c=getCanvas();"
        "if(!c){setTimeout(installPower,150);return;}"
        "if(document.getElementById('pool-power-v42'))return;"

        "const p=document.createElement('div');"
        "p.id='pool-power-v42';"
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

        "let powerTouchId=null,anchorX=0,anchorY=0,current=0;"
        "const setVisual=v=>{v=clamp(v,0,1);current=v;fill.style.height=(v*100)+'%';knob.style.top=(v*100)+'%';pct.textContent=Math.round(v*100)+'%';};"
        "const fromTouch=t=>{const r=track.getBoundingClientRect();return clamp((t.clientY-r.top)/r.height,0,1);};"

        "nativeAdd.call(track,'touchstart',e=>{"
          "if(!e.changedTouches.length || powerTouchId!==null)return;kill(e);"
          "const t=e.changedTouches[0],r=c.getBoundingClientRect();"
          "anchorX=r.left+r.width*0.50;anchorY=r.top+r.height*0.48;"
          "powerTouchId=t.identifier;const v=fromTouch(t);setVisual(v);"
          "sendMouse('mousedown',anchorX,anchorY,1);"
          "sendMouse('mousemove',anchorX,anchorY+v*POWER_DRAG_PX,1);"
        "},{capture:true,passive:false});"

        "nativeAdd.call(track,'touchmove',e=>{"
          "if(powerTouchId===null)return;"
          "const t=findTouch(e.changedTouches,powerTouchId);"
          "if(!t)return;kill(e);"
          "const v=fromTouch(t);setVisual(v);"
          "sendMouse('mousemove',anchorX,anchorY+v*POWER_DRAG_PX,1);"
        "},{capture:true,passive:false});"

        "nativeAdd.call(track,'touchend',e=>{"
          "if(powerTouchId===null)return;"
          "const t=findTouch(e.changedTouches,powerTouchId);"
          "if(!t)return;kill(e);"
          "sendMouse('mouseup',anchorX,anchorY+current*POWER_DRAG_PX,0);"
          "powerTouchId=null;setTimeout(()=>setVisual(0),250);"
        "},{capture:true,passive:false});"

        "nativeAdd.call(track,'touchcancel',e=>{"
          "if(powerTouchId===null)return;"
          "const t=findTouch(e.changedTouches,powerTouchId);"
          "if(!t)return;kill(e);"
          "sendMouse('mouseup',anchorX,anchorY+current*POWER_DRAG_PX,0);"
          "powerTouchId=null;setTimeout(()=>setVisual(0),250);"
        "},{capture:true,passive:false});"

        "setVisual(0);"
        "console.log('[TouchFixV4.2] power installed');"
      "};"

      "installPower();"
      "nativeAdd.call(document,'DOMContentLoaded',installPower,{once:true});"
      "new MutationObserver(installPower).observe(document.documentElement||document,{childList:true,subtree:true});"
      "console.log('[TouchFixV4.2] loaded');"
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
    self.status.text = @"TOUCH FIX V4.2 • tap=click, drag=aim (under finger)";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.76];
    self.status.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 9;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *url=[NSURL URLWithString:@"https://0wwafa.github.io/8ball/?utm_source=touchfixv42"];
    [self.web loadRequest:[NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:45]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.status.hidden=NO;
    self.status.text=@"TOUCH FIX V4.2 ACTIVE • tap=click • drag=aim(under finger) • slider=power";
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
