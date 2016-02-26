#import "THtmlViewController.h"
#import "BackButtonHandler.h"

@implementation HtmlViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.title = self.pageTitle;
	self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.indicator.color = [UIColor blackColor];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.indicator];

	UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	webView.dataDetectorTypes = UIDataDetectorTypeNone;
	webView.scalesPageToFit = YES;
	webView.delegate = self;

	[webView loadRequest:[[NSURLRequest alloc] initWithURL:self.url]];
	self.view = webView;
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

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[self.indicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[self.indicator stopAnimating];
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

@end
