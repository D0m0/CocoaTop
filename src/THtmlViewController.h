#import <UIKit/UIKit.h>

@interface HtmlViewController : UIViewController<UIWebViewDelegate>
@property(retain) NSURL *url;
@property(retain) NSString *pageTitle;
@property(retain) UIActivityIndicatorView *indicator;
- (id)initWithURL:(NSString *)url title:(NSString *)title;
@end
