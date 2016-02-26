#import "Compat.h"
#import "PopupMenuView.h"

@interface UITableViewControllerWithMenu()
@property (strong) UIView *menuContainerView;
@property (strong) UIView *menuTintView;
@property (strong) UIView *menuView;
@end

@interface UIButtonWithColorStates : UIButton
@end

@implementation UIButtonWithColorStates
- (UIColor *)colorForHigh:(BOOL)high sel:(BOOL)sel
{
	return high ? [UIColor colorWithRed:( 16.0 / 255.0) green:( 84.0 / 255.0) blue:(152.0 / 255.0) alpha:1.0]:
			sel ? [UIColor colorWithRed:(101.0 / 255.0) green:(170.0 / 255.0) blue:(239.0 / 255.0) alpha:1.0]:
				  [UIColor colorWithRed:( 36.0 / 255.0) green:(132.0 / 255.0) blue:(232.0 / 255.0) alpha:1.0];
}

- (void)setHighlighted:(BOOL)highlighted
{
	self.backgroundColor = [self colorForHigh:highlighted sel:self.selected];
	[super setHighlighted:highlighted];
}

- (void)setSelected:(BOOL)selected
{
	self.backgroundColor = [self colorForHigh:self.highlighted sel:selected];
	[super setSelected:selected];
}
@end

@implementation UITableViewControllerWithMenu

- (void)popupMenuLayout
{
	if ([self.menuContainerView superview] != nil) {
		CGRect frame = [self.navigationController.view convertRect:self.view.frame fromView:self.view.superview];
		frame.origin.y += self.tableView.contentInset.top;
		frame.size.height -= self.tableView.contentInset.top;
		[self.menuContainerView setFrame:frame];
		for (UIButton *button in self.menuView.subviews)
			button.selected = button.tag == self.popupMenuSelected;
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	[self popupMenuLayout];
}

- (IBAction)popupMenuToggle
{
	const BOOL willAppear = (self.menuContainerView.superview == nil);
	if (willAppear) {
		[self.navigationController.view addSubview:self.menuContainerView];
		[self popupMenuLayout];
	}
	// Show/hide animation
	CGRect menuFrame = self.menuView.frame;
	menuFrame.origin.y = willAppear ? 0.0 : -menuFrame.size.height;
	CGFloat menuTintAlpha = willAppear ? 0.7 : 0.0;
	void (^animations)(void) = ^ {
		self.menuView.frame = menuFrame;
		self.menuTintView.alpha = menuTintAlpha;
	};
	void (^completion)(BOOL) = ^(BOOL finished) {
		if (!willAppear) [self.menuContainerView removeFromSuperview];
	};
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0)
		[UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:1.0
			initialSpringVelocity:4.0 options:UIViewAnimationOptionCurveEaseInOut
			animations:animations completion:completion];
	else
#endif
		[UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut
			animations:animations completion:completion];
}

- (void)popupMenuItemTapped:(UIButton *)sender
{
	[self popupMenuToggle];
	if ([self respondsToSelector:@selector(popupMenuTappedItem:)])
		[self popupMenuTappedItem:sender.tag];
}

- (UIButton *)popupMenuButtonWithTitle:(NSString *)title position:(NSInteger)position aligned:(UIControlContentHorizontalAlignment)align
{
	const CGFloat buttonHeight = 45.0;
	UIButtonWithColorStates *button = [UIButtonWithColorStates buttonWithType:UIButtonTypeCustom];
	button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	button.frame = CGRectMake(0.0, position * (1.0 + buttonHeight), 0.0, buttonHeight);
	button.tag = position;
	button.contentEdgeInsets = UIEdgeInsetsMake(0, buttonHeight / 2, 0, buttonHeight / 2);
	button.selected = self.popupMenuSelected == position;
	button.contentHorizontalAlignment = align;
	[button addTarget:self action:@selector(popupMenuItemTapped:) forControlEvents:UIControlEventTouchUpInside];
	[button setTitle:title forState:UIControlStateNormal];
	return button;
}

- (void)popupMenuWithItems:(NSArray *)items selected:(NSInteger)sel aligned:(UIControlContentHorizontalAlignment)align
{
	const CGFloat buttonHeight = 45.0;
	const CGFloat menuHeight = items.count * (1.0 + buttonHeight);
	UIView *menuView = [[UIView alloc] initWithFrame:CGRectMake(0.0, -menuHeight, 0.0, menuHeight)];
	menuView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	menuView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
	self.popupMenuSelected = sel;
	NSInteger pos = 0;
	for (NSString* item in items) {
		[menuView addSubview:[self popupMenuButtonWithTitle:item position:pos aligned:align]];
		pos++;
	}
	self.menuView = menuView;

	UIView *menuTintView = [[UIView alloc] initWithFrame:CGRectZero];
	menuTintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	menuTintView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
	// Add tap recognizer to dismiss menu when tapping outside its bounds.
	[menuTintView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(popupMenuToggle)]];
	self.menuTintView = menuTintView;

	UIView *menuContainerView = [[UIView alloc] initWithFrame:CGRectZero];
	menuContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	menuContainerView.clipsToBounds = YES;
	[menuContainerView addSubview:self.menuTintView];
	[menuContainerView addSubview:self.menuView];
	self.menuContainerView = menuContainerView;
}

- (void)viewDidUnload
{
	if (self.menuContainerView != nil) {
		[self.menuContainerView removeFromSuperview];
		self.menuContainerView = nil;
		self.menuTintView = nil;
		self.menuView = nil;
	}
	[super viewDidUnload];
}

@end
