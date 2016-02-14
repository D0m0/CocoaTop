#import "THtmlViewController.h"
#import "UIViewController+BackButtonHandler.h"

@implementation HtmlViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.title = self.pageTitle;
	UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	webView.dataDetectorTypes = UIDataDetectorTypeNone;
//	webView.scalesPageToFit = YES;

	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.url];
	[webView loadRequest:request];
	[request release];
	self.view = webView;
	[webView release];
}

- (BOOL)navigationShouldPopOnBackButton
{
	UIWebView *webView = (UIWebView *)self.view;
	if (webView.canGoBack) {
		[webView goBack];
		return NO;
	}
	return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (id)initWithURL:(NSString *)url title:(NSString *)title;
{
	self = [super init];
	if (self != nil) {
		self.url = [[NSBundle mainBundle] URLForResource:url withExtension:@"html"];
		self.pageTitle = title;
	}
	return self;
}

- (void)dealloc
{
	[_url release];
	[_pageTitle release];
	[super dealloc];
}

@end
