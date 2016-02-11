#import "THtmlViewController.h"

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

- (void)handleTapBehind:(UITapGestureRecognizer *)sender
{
	if (sender.state == UIGestureRecognizerStateEnded) {
		CGPoint location = [sender locationInView:self.view];
		if (![self.view pointInside:location withEvent:nil]) {
			[self.view.window removeGestureRecognizer:sender];
			[self dismissViewControllerAnimated:YES completion:nil];
		}
	}
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
