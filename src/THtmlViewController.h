#import <UIKit/UIKit.h>

@interface HtmlViewController : UIViewController<UIWebViewDelegate>
@property(strong) NSURL *url;
@property(strong) NSString *pageTitle;
@property(strong) UIActivityIndicatorView *indicator;
- (id)initWithURL:(NSString *)url title:(NSString *)title;
@end
