#import <UIKit/UIKit.h>

@interface TextViewController : UIViewController<UIGestureRecognizerDelegate>
@property(retain) NSString *textString;
@property(retain) NSString *titleString;
@property(retain) UITapGestureRecognizer *tapBehind;
+ (void)showText:(NSString *)text withTitle:(NSString *)title inViewController:(UIViewController *)parent;
@end
