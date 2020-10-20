#import "AppDelegate.h"
#import "RootViewController.h"

@implementation RootTabMaskController

-(instancetype)init {
    if (self = [super init]) {
        controller = [RootViewController new];
        [self addChildViewController: controller];
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview: controller.view];
    if (@available(iOS 11, *)) {
        mask = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        mask.translatesAutoresizingMaskIntoConstraints = NO;
        if (@available(iOS 13, *)) {
            mask.backgroundColor = [UIColor colorWithDynamicProvider:^(UITraitCollection *collection) {
                if (collection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithWhite:.31 alpha:.85];
                } else {
                    return [UIColor colorWithWhite:.75 alpha:.85];
                }
            }];
        } else {
            mask.backgroundColor = [UIColor colorWithWhite:.75 alpha:.85];
        }
        [self.view addSubview: mask];
        [self.view bringSubviewToFront: mask];
    }
}

-(void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (@available(iOS 11, *)) {
        UIEdgeInsets insets = self.view.safeAreaInsets;
        if (insets.bottom != 0) {
            mask.hidden = false;
            mask.frame = CGRectMake(0, self.view.bounds.size.height - insets.bottom, self.view.bounds.size.width, insets.bottom);
            [self.view bringSubviewToFront: mask];
        } else {
            mask.hidden = true;
        }
    }
    if (controller.view != nil) {
        controller.view.frame = self.view.frame;
    }
}

@end

@implementation TopAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //[UITableView appearance].estimatedRowHeight = 0;
    [UITableView appearance].rowHeight = 44;
    [UITableView appearance].sectionHeaderHeight = 23;
    [UITableView appearance].sectionFooterHeight = 23;
    if (@available(iOS 11, *)) {
        [UIScrollView appearance].contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    }
	// Create UIWindow
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	// Allocate the navigation controller
	self.navigationController = [[UINavigationController alloc] initWithRootViewController:[RootTabMaskController new]];
	// Set the navigation controller as the window's root view controller and display.
	self.window.rootViewController = self.navigationController;
	[self.window makeKeyAndVisible];
	return YES;
}
/*
- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	// If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. See also applicationDidEnterBackground:.
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	// Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
}
*/
@end
