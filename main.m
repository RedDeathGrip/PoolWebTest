#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface VC : UIViewController <WKNavigationDelegate>
@property(nonatomic,strong) WKWebView *web;
@property(nonatomic,strong) UILabel *status;
@end

@implementation VC

- (WKUserScript *)script:(NSString *)source time:(WKUserScriptInjectionTime)time {
    if (@available(iOS 14.0, *)) {
        return [[WKUserScript alloc] initWithSource:source
                                     injectionTime:time
                                  forMainFrameOnly:NO
                                    inContentWorld:WKContentWorld.pageWorld];
    }
    return [[WKUserScript alloc] initWithSource:source
                                 injectionTime:time
                              forMainFrameOnly:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    cfg.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    cfg.allowsInlineMediaPlayback = YES;
    cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    if (@available(iOS 13.0, *)) {
        WKWebpagePreferences *prefs = [WKWebpagePreferences new];
        prefs.preferredContentMode = WKContentModeDesktop;
        cfg.defaultWebpagePreferences = prefs;
    }

    // Stronger PC spoof. IMPORTANT: injected into ALL frames, not only the top page.
    NSString *spoof =
    @"(() => {"
      "const def=(obj,key,val)=>{try{Object.defineProperty(obj,key,{get:()=>val,configurable:true});}catch(e){}};"
      "def(Navigator.prototype,'platform','Win32');"
      "def(Navigator.prototype,'maxTouchPoints',0);"
      "def(Navigator.prototype,'vendor','Google Inc.');"
      "def(Navigator.prototype,'webdriver',false);"
      "def(Navigator.prototype,'appVersion','5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/151.0.0.0 Safari/537.36');"
      "const uad={brands:[{brand:'Chromium',version:'151'},{brand:'Google Chrome',version:'151'}],"
        "mobile:false,platform:'Windows',"
        "getHighEntropyValues:async()=>({architecture:'x86',bitness:'64',mobile:false,model:'',platform:'Windows',platformVersion:'10.0.0',uaFullVersion:'151.0.0.0'})};"
      "def(Navigator.prototype,'userAgentData',uad);"
      "try{delete Window.prototype.ontouchstart;delete window.ontouchstart;}catch(e){}"

      // Force a DESKTOP layout width. A phone-sized layout can itself trigger the 'Get app' UI.
      "const forceViewport=()=>{"
        "try{"
          "let h=document.head||document.documentElement;"
          "if(!h)return;"
          "let v=document.querySelector('meta[name=viewport]');"
          "if(!v){v=document.createElement('meta');v.name='viewport';h.appendChild(v);}"
          "v.setAttribute('content','width=1280, initial-scale=0.30, minimum-scale=0.20, maximum-scale=1.0, user-scalable=yes');"
        "}catch(e){}"
      "};"
      "forceViewport();"
      "new MutationObserver(forceViewport).observe(document.documentElement||document,{childList:true,subtree:true});"

      // Desktop pointer / hover media-query answers.
      "const realMM=window.matchMedia.bind(window);"
      "window.matchMedia=(q)=>{"
        "const s=String(q).toLowerCase();"
        "const fake=(m)=>({matches:m,media:q,onchange:null,addListener(){},removeListener(){},addEventListener(){},removeEventListener(){},dispatchEvent(){return true;}});"
        "if(s.includes('pointer: coarse')||s.includes('any-pointer: coarse')||s.includes('hover: none'))return fake(false);"
        "if(s.includes('pointer: fine')||s.includes('any-pointer: fine')||s.includes('hover: hover')||s.includes('any-hover: hover'))return fake(true);"
        "return realMM(q);"
      "};"
    "})();";

    [cfg.userContentController addUserScript:[self script:spoof time:WKUserScriptInjectionTimeAtDocumentStart]];

    // Translate finger input to the mouse events expected by the PC game.
    NSString *touch =
    @"(() => {"
      "function hook(){"
        "const els=[...document.querySelectorAll('canvas')];"
        "if(!els.length){setTimeout(hook,250);return;}"
        "for(const canvas of els){"
          "if(canvas.dataset.touchmouse==='1')continue;"
          "canvas.dataset.touchmouse='1';canvas.style.touchAction='none';"
          "let down=false,moved=false,lastTap=0,sx=0,sy=0;"
          "const mouse=(type,t,buttons)=>{"
            "const target=document.elementFromPoint(t.clientX,t.clientY)||canvas;"
            "target.dispatchEvent(new MouseEvent(type,{bubbles:true,cancelable:true,view:window,"
              "clientX:t.clientX,clientY:t.clientY,screenX:t.screenX,screenY:t.screenY,button:0,buttons}));"
          "};"
          "canvas.addEventListener('touchstart',e=>{"
            "if(!e.changedTouches.length)return;e.preventDefault();"
            "const t=e.changedTouches[0],now=Date.now();sx=t.clientX;sy=t.clientY;moved=false;"
            "if(now-lastTap>0&&now-lastTap<330){down=true;mouse('mousedown',t,1);}else down=false;"
            "lastTap=now;"
          "},{capture:true,passive:false});"
          "canvas.addEventListener('touchmove',e=>{"
            "if(!e.changedTouches.length)return;e.preventDefault();const t=e.changedTouches[0];"
            "if(Math.hypot(t.clientX-sx,t.clientY-sy)>4)moved=true;"
            "mouse('mousemove',t,down?1:0);"
          "},{capture:true,passive:false});"
          "canvas.addEventListener('touchend',e=>{"
            "if(!e.changedTouches.length)return;e.preventDefault();const t=e.changedTouches[0];"
            "if(down){mouse('mouseup',t,0);down=false;}else if(!moved){mouse('mousedown',t,1);mouse('mouseup',t,0);}"
          "},{capture:true,passive:false});"
        "}"
      "}"
      "if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',hook);else hook();"
      "new MutationObserver(hook).observe(document.documentElement||document,{childList:true,subtree:true});"
    "})();";
    [cfg.userContentController addUserScript:[self script:touch time:WKUserScriptInjectionTimeAtDocumentEnd]];

    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:cfg];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.customUserAgent =
      @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
       "KHTML, like Gecko Chrome/151.0.0.0 Safari/537.36";
    self.web.scrollView.bounces = NO;
    [self.view addSubview:self.web];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(8, 38, self.view.bounds.size.width-16, 54)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.status.numberOfLines = 2;
    self.status.text = @"FULL PC SPOOF v2 loading…";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78];
    self.status.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 9;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *url=[NSURL URLWithString:@"https://8ballpool.com/en/game"];
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:url
                                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                              timeoutInterval:45];
    [self.web loadRequest:r];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *js=@"JSON.stringify({platform:navigator.platform,touch:navigator.maxTouchPoints,ua:navigator.userAgent,mobile:navigator.userAgentData?navigator.userAgentData.mobile:'na',iw:innerWidth,ow:outerWidth,url:location.href})";
    [webView evaluateJavaScript:js completionHandler:^(id value,NSError *err){
        self.status.text = err ? @"FULL PC SPOOF v2 • diagnostic failed" :
          [NSString stringWithFormat:@"FULL PC SPOOF v2\n%@", value ?: @"no diagnostic"];
        [self.view bringSubviewToFront:self.status];
    }];
}

// Stop App Store schemes from kicking us out of the test app.
- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)action
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *scheme=action.request.URL.scheme.lowercaseString;
    NSString *host=action.request.URL.host.lowercaseString;
    if ([scheme isEqualToString:@"itms-apps"] ||
        [scheme isEqualToString:@"itms-appss"] ||
        [scheme isEqualToString:@"itms-services"] ||
        ([host containsString:@"apps.apple.com"])) {
        self.status.text=@"Blocked App Store redirect — page still thinks mobile";
        [self.view bringSubviewToFront:self.status];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
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
