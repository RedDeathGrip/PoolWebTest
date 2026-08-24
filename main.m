#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface VC : UIViewController <WKNavigationDelegate>
@property(nonatomic,strong) WKWebView *web;
@property(nonatomic,strong) UILabel *status;
@end

@implementation VC

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

    // Run BEFORE the site's own JavaScript.
    NSString *spoof =
    @"(() => {"
     "const def=(obj,key,getter)=>{try{Object.defineProperty(obj,key,{get:getter,configurable:true});}catch(e){}};"
     "def(Navigator.prototype,'platform',()=> 'Win32');"
     "def(Navigator.prototype,'maxTouchPoints',()=> 0);"
     "def(Navigator.prototype,'vendor',()=> 'Google Inc.');"
     "def(Navigator.prototype,'webdriver',()=> false);"
     "def(Navigator.prototype,'appVersion',()=> '5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/151.0.0.0 Safari/537.36');"
     "const uad={"
       "brands:[{brand:'Chromium',version:'151'},{brand:'Google Chrome',version:'151'},{brand:'Not_A Brand',version:'99'}],"
       "mobile:false,"
       "platform:'Windows',"
       "getHighEntropyValues:async(keys)=>({architecture:'x86',bitness:'64',mobile:false,model:'',platform:'Windows',platformVersion:'10.0.0',uaFullVersion:'151.0.0.0',fullVersionList:[{brand:'Chromium',version:'151.0.0.0'},{brand:'Google Chrome',version:'151.0.0.0'}]})"
     "};"
     "def(Navigator.prototype,'userAgentData',()=>uad);"
     "try{def(Screen.prototype,'width',()=>1920);def(Screen.prototype,'height',()=>1080);def(Screen.prototype,'availWidth',()=>1920);def(Screen.prototype,'availHeight',()=>1040);}catch(e){}"
     "try{def(window,'devicePixelRatio',()=>1);}catch(e){}"
     "try{delete window.ontouchstart; delete Window.prototype.ontouchstart;}catch(e){}"

     // Make pointer/hover media queries look like a desktop mouse.
     "const mm=window.matchMedia.bind(window);"
     "window.matchMedia=(q)=>{"
       "const s=String(q).toLowerCase();"
       "if(s.includes('pointer: coarse')||s.includes('any-pointer: coarse')||s.includes('hover: none'))"
         "return {matches:false,media:q,onchange:null,addListener(){},removeListener(){},addEventListener(){},removeEventListener(){},dispatchEvent(){return true;}};"
       "if(s.includes('pointer: fine')||s.includes('any-pointer: fine')||s.includes('hover: hover')||s.includes('any-hover: hover'))"
         "return {matches:true,media:q,onchange:null,addListener(){},removeListener(){},addEventListener(){},removeEventListener(){},dispatchEvent(){return true;}};"
       "return mm(q);"
     "};"

     // Light WebGL renderer disguise for sites doing basic device checks.
     "try{"
       "const patch=(P)=>{if(!P||!P.getParameter)return;const old=P.getParameter;P.getParameter=function(x){if(x===37445)return 'Google Inc. (NVIDIA)';if(x===37446)return 'ANGLE (NVIDIA GeForce GTX 1660 Direct3D11)';return old.call(this,x);};};"
       "patch(window.WebGLRenderingContext&&WebGLRenderingContext.prototype);"
       "patch(window.WebGL2RenderingContext&&WebGL2RenderingContext.prototype);"
     "}catch(e){}"
     "})();";

    WKUserScript *s1;
    if (@available(iOS 14.0, *)) {
        s1 = [[WKUserScript alloc] initWithSource:spoof
                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                forMainFrameOnly:YES
                                  inContentWorld:WKContentWorld.pageWorld];
    } else {
        s1 = [[WKUserScript alloc] initWithSource:spoof
                                   injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                forMainFrameOnly:YES];
    }
    [cfg.userContentController addUserScript:s1];

    // Touch -> desktop mouse controls.
    // Normal finger drag = move mouse to aim.
    // Tap = click.
    // Double-tap, then drag = hold left mouse (shot-power gesture); release = mouseup.
    NSString *touchMap =
    @"(() => {"
      "let installed=false;"
      "function install(){"
        "if(installed)return;"
        "const canvas=document.querySelector('canvas#engine, canvas.engine, canvas');"
        "if(!canvas){setTimeout(install,300);return;}"
        "installed=true;"
        "canvas.style.touchAction='none';"
        "let lastTap=0, down=false, moved=false, startX=0, startY=0;"
        "const mouse=(type,t,buttons)=>{"
          "const target=document.elementFromPoint(t.clientX,t.clientY)||canvas;"
          "target.dispatchEvent(new MouseEvent(type,{bubbles:true,cancelable:true,view:window,"
          "screenX:t.screenX,screenY:t.screenY,clientX:t.clientX,clientY:t.clientY,"
          "button:0,buttons:buttons}));"
        "};"
        "canvas.addEventListener('touchstart',e=>{"
          "if(!e.changedTouches.length)return;e.preventDefault();"
          "const t=e.changedTouches[0], now=Date.now();"
          "startX=t.clientX;startY=t.clientY;moved=false;"
          "if(now-lastTap>0 && now-lastTap<320){down=true;mouse('mousedown',t,1);}else{down=false;}"
          "lastTap=now;"
        "},{capture:true,passive:false});"
        "canvas.addEventListener('touchmove',e=>{"
          "if(!e.changedTouches.length)return;e.preventDefault();"
          "const t=e.changedTouches[0];"
          "if(Math.hypot(t.clientX-startX,t.clientY-startY)>4)moved=true;"
          "mouse('mousemove',t,down?1:0);"
        "},{capture:true,passive:false});"
        "canvas.addEventListener('touchend',e=>{"
          "if(!e.changedTouches.length)return;e.preventDefault();"
          "const t=e.changedTouches[0];"
          "if(down){mouse('mouseup',t,0);down=false;}"
          "else if(!moved){mouse('mousedown',t,1);mouse('mouseup',t,0);}"
        "},{capture:true,passive:false});"
        "canvas.addEventListener('touchcancel',e=>{"
          "if(e.changedTouches.length && down){mouse('mouseup',e.changedTouches[0],0);}down=false;"
        "},{capture:true,passive:false});"
      "}"
      "if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();"
      "new MutationObserver(()=>install()).observe(document.documentElement||document,{childList:true,subtree:true});"
    "})();";

    WKUserScript *s2;
    if (@available(iOS 14.0, *)) {
        s2 = [[WKUserScript alloc] initWithSource:touchMap
                                   injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                forMainFrameOnly:YES
                                  inContentWorld:WKContentWorld.pageWorld];
    } else {
        s2 = [[WKUserScript alloc] initWithSource:touchMap
                                   injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                forMainFrameOnly:YES];
    }
    [cfg.userContentController addUserScript:s2];

    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:cfg];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.web.scrollView.scrollEnabled = NO;
    self.web.scrollView.bounces = NO;

    // Server-side desktop identity.
    self.web.customUserAgent =
      @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
       "AppleWebKit/537.36 (KHTML, like Gecko) "
       "Chrome/151.0.0.0 Safari/537.36";

    [self.view addSubview:self.web];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(12, 42, 330, 38)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    self.status.text = @"PC spoof + touch controls loading…";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
    self.status.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 10;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *url = [NSURL URLWithString:@"https://8ballpool.com/en/game"];
    NSMutableURLRequest *req =
      [NSMutableURLRequest requestWithURL:url
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                          timeoutInterval:45];
    [self.web loadRequest:req];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *check =
      @"JSON.stringify({ua:navigator.userAgent,platform:navigator.platform,"
       "touch:navigator.maxTouchPoints,mobile:navigator.userAgentData&&navigator.userAgentData.mobile,"
       "url:location.href})";
    [webView evaluateJavaScript:check completionHandler:^(id value, NSError *error) {
        if ([value isKindOfClass:NSString.class]) {
            self.status.text = [NSString stringWithFormat:@"Spoof active • %@", [(NSString*)value substringToIndex:MIN((NSUInteger)70,[(NSString*)value length])]];
        } else {
            self.status.text = @"Page loaded • spoof check unavailable";
        }
    }];
    [self.view bringSubviewToFront:self.status];
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    self.status.text = [NSString stringWithFormat:@"Load error: %@",error.localizedDescription];
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
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
