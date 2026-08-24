#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface VC : UIViewController <WKNavigationDelegate>
@property(nonatomic,strong) WKWebView *web;
@end

@implementation VC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    cfg.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    cfg.allowsInlineMediaPlayback = YES;
    cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:cfg];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.navigationDelegate = self;
    self.web.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.web];

    NSURL *u = [NSURL URLWithString:@"https://www.miniclip.com/games/8-ball-pool/"];
    [self.web loadRequest:[NSURLRequest requestWithURL:u]];
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

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
