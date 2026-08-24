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
    cfg.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    cfg.allowsInlineMediaPlayback = YES;
    cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    if (@available(iOS 13.0, *)) {
        WKWebpagePreferences *prefs = [WKWebpagePreferences new];
        prefs.preferredContentMode = WKContentModeDesktop;
        cfg.defaultWebpagePreferences = prefs;
    }

    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:cfg];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    // IMPORTANT: fully replace the iPhone UA with a desktop Chrome UA.
    // The first beta only appended text to the iPhone UA, so Miniclip correctly
    // detected a phone and showed "Get 8 Ball Pool".
    self.web.customUserAgent =
        @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
         "AppleWebKit/537.36 (KHTML, like Gecko) "
         "Chrome/151.0.0.0 Safari/537.36";

    [self.view addSubview:self.web];

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(12, 44, 220, 34)];
    self.status.text = @"Desktop mode loading…";
    self.status.textColor = UIColor.whiteColor;
    self.status.backgroundColor = [UIColor colorWithWhite:0 alpha:0.65];
    self.status.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.layer.cornerRadius = 10;
    self.status.clipsToBounds = YES;
    [self.view addSubview:self.status];

    NSURL *u = [NSURL URLWithString:@"https://www.miniclip.com/games/8-ball-pool/"];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:u
                                                   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                               timeoutInterval:30];
    [r setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
forHTTPHeaderField:@"Accept"];
    [self.web loadRequest:r];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.status.text = @"Desktop page loaded";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.status.hidden = YES;
    });
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    self.status.text = [NSString stringWithFormat:@"Load error: %@", error.localizedDescription];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    self.status.text = [NSString stringWithFormat:@"Load error: %@", error.localizedDescription];
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [VC new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
