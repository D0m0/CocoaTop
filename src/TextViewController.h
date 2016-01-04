#import <UIKit/UIKit.h>

@interface TextViewController : UIViewController<UIGestureRecognizerDelegate>
@property(retain) NSString *textString;
@property(retain) NSString *titleString;
+ (void)showText:(NSString *)text withTitle:(NSString *)title inViewController:(UIViewController *)parent;
@end
