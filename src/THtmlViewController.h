#import <UIKit/UIKit.h>

@interface HtmlViewController : UIViewController
@property(retain) NSURL *url;
@property(retain) NSString *pageTitle;
- (id)initWithURL:(NSString *)url title:(NSString *)title;
@end
