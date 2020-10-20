#import <UIKit/UIKit.h>

@interface TopAppDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigationController;
@end

@class RootViewController;
@interface RootTabMaskController : UIViewController {
    UIView *mask;
    RootViewController *controller;
}

@end
