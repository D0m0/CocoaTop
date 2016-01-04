#import "TextViewController.h"

@implementation TextViewController

- (void)loadView
{
    [super loadView];
	// Text and title
	self.title = self.titleString;
	UITextView* textView = [[UITextView alloc] initWithFrame:CGRectZero textContainer:nil];
	textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	textView.editable = NO;
	textView.font = [UIFont systemFontOfSize:16.0];
	textView.text = self.textString;
	self.view = textView;
	[textView release];
	// Done button
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
		target:self action:@selector(dismissViewController)];
	self.navigationItem.rightBarButtonItem = doneButton;
	[doneButton release];
}

- (void)dismissViewController
{
	[self dismissViewControllerAnimated:NO completion:nil];
}

- (void)handleTapBehind:(UITapGestureRecognizer *)sender
{
	if (sender.state == UIGestureRecognizerStateEnded) {
		CGPoint location = [sender locationInView:self.view];
		if (![self.view pointInside:location withEvent:nil]) {
			[self.view.window removeGestureRecognizer:sender];
			[self dismissViewControllerAnimated:NO completion:nil];
		}
	}
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{ return YES; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{ return YES; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{ return YES; }

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapBehind:)];
	[recognizer setNumberOfTapsRequired:1];
	recognizer.cancelsTouchesInView = NO;
	[self.view.window addGestureRecognizer:recognizer];
	recognizer.delegate = self;
}

+ (void)showText:(NSString *)text withTitle:(NSString *)title inViewController:(UIViewController *)parent
{
	TextViewController *controller = [[TextViewController alloc] init];//WithText:text withTitle:title];
	controller.textString = text;
	controller.titleString = title;
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
	[controller release];
	navController.modalPresentationStyle = UIModalPresentationFormSheet;
//	navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[parent presentViewController:navController animated:NO completion:nil];
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone) {
		navController.view.superview.layer.cornerRadius = 10.0;
		navController.view.superview.layer.borderColor = [UIColor clearColor].CGColor;
//		navController.view.superview.layer.borderWidth = 2;
		navController.view.superview.clipsToBounds = YES;
	}
	[navController release];
}

- (void)dealloc
{
	[_titleString release];
	[_textString release];
	[super dealloc];
}

@end
