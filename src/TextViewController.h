#import <UIKit/UIKit.h>

@interface TextViewController : UIViewController<UIGestureRecognizerDelegate>
@property(strong) NSString *textString;
@property(strong) NSString *titleString;
@property(strong) UITapGestureRecognizer *tapBehind;
+ (void)showText:(NSString *)text withTitle:(NSString *)title inViewController:(UIViewController *)parent;
@end
