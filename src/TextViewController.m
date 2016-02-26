#import "Compat.h"
#import "TextViewController.h"

@implementation TextViewController

- (void)loadView
{
	[super loadView];
	// Text and title
	self.title = self.titleString;
	UITextView* textView = [[UITextView alloc] initWithFrame:CGRectZero];
	textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	textView.editable = NO;
	textView.font = [UIFont systemFontOfSize:16.0];
	textView.text = self.textString;
	self.view = textView;
	// Done button
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
		target:self action:@selector(dismissViewController)];
}

- (void)dismissViewController
{
	[self dismissViewControllerAnimated:NO completion:nil];
}

- (void)handleTapBehind:(UITapGestureRecognizer *)sender
{
	if (sender.state == UIGestureRecognizerStateEnded)
		if (![self.view pointInside:[sender locationInView:self.view] withEvent:nil])
			[self dismissViewControllerAnimated:NO completion:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	self.tapBehind = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapBehind:)];
	[self.tapBehind setNumberOfTapsRequired:1];
	self.tapBehind.cancelsTouchesInView = NO;
	self.tapBehind.delegate = self;
	[self.view.window addGestureRecognizer:self.tapBehind];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self.view.window removeGestureRecognizer:self.tapBehind];
	self.tapBehind = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{ return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown; }
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{ return YES; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{ return YES; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{ return YES; }

+ (void)showText:(NSString *)text withTitle:(NSString *)title inViewController:(UIViewController *)parent
{
	TextViewController *controller = [[TextViewController alloc] init];//WithText:text withTitle:title];
	controller.textString = text;
	controller.titleString = title;
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
	navController.modalPresentationStyle = UIModalPresentationFormSheet;
//	navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[parent presentViewController:navController animated:NO completion:nil];
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
		navController.view.superview.layer.cornerRadius = 10.0;
		navController.view.superview.layer.borderColor = [UIColor clearColor].CGColor;
#endif
//		navController.view.superview.layer.borderWidth = 2;
		navController.view.superview.clipsToBounds = YES;
	}
}

@end
