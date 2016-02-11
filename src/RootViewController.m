#import "RootViewController.h"
#import "SockViewController.h"
#import "Setup.h"
#import "SetupColumns.h"
#import "About.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"
#import "ProcArray.h"
#import "THtmlViewController.h"

#define NTSTAT_PREQUERY_INTERVAL	0.1

@interface RootViewController()
@property (retain) GridHeaderView *header;
@property (retain) GridHeaderView *footer;
@property (retain) PSProcArray *procs;
@property (retain) NSTimer *timer;
@property (retain) UILabel *status;
@property (retain) NSArray *columns;
@property (retain) PSColumn *sorter;
@property (assign) BOOL sortdesc;
@property (assign) BOOL fullScreen;
@property (assign) CGFloat interval;
@property (assign) NSUInteger configId;
@property (retain) NSString *configChange;
@property (assign) pid_t selectedPid;

@property (nonatomic, readonly) UIView *menuContainerView;
@property (nonatomic, readonly) UIView *menuTintView;
@property (nonatomic, readonly) UIView *menuView;
@end

@implementation RootViewController

@synthesize menuContainerView = _menuContainerView;
@synthesize menuTintView = _menuTintView;
@synthesize menuView = _menuView;

- (void)tapped:(UIButton *)sender
{
	[self openActionSheet];
	UIViewController* view = nil;
	switch (sender.tag) {
	case 0: view = [[SetupViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	case 1: view = [[SetupColsViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	case 2: view = [[HtmlViewController alloc] initWithURL:@"guide" title:@"Quick Guide"]; break;
	case 3: view = [[AboutViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	}
	if (view) {
		[self.navigationController pushViewController:view animated:YES];
		[view release];
	}
}

/*
- (void)presentHelpForName:(NSString *)name
{
	NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"html" subdirectory:@"Documentation"];
	if (url != nil) {
		TSHTMLViewController *controller = [[TSHTMLViewController alloc] initWithURL:url];
		controller.title = NSLocalizedString(name, nil);
		[self.navigationController pushViewController:controller animated:YES];
		[controller release];
	}
}

- (void)helpButtonTapped
{
	[self presentHelpForName:@"REPORT_OVERVIEW"];
}
*/
static UIButton *menuButton(NSUInteger position, NSString *title, id target, SEL action)
{
	const CGFloat buttonHeight = 45.0;
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	button.frame = CGRectMake(0.0, position * (1.0 + buttonHeight), 0.0, buttonHeight);
	button.tag = position;
	button.contentEdgeInsets = UIEdgeInsetsMake(0, buttonHeight / 2, 0, 0);
	button.backgroundColor = [UIColor colorWithRed:(36.0 / 255.0) green:(132.0 / 255.0) blue:(232.0 / 255.0) alpha:1.0];
	button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
	[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	[button setTitle:title forState:UIControlStateNormal];
	return button;
}

- (UIView *)menuView
{
	if (_menuView == nil) {
		const CGFloat buttonHeight = 45.0;
		const CGFloat menuHeight = 4.0 * (1.0 + buttonHeight);
		UIView *menuView = [[UIView alloc] initWithFrame:CGRectMake(0.0, -menuHeight, 0.0, menuHeight)];
		menuView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		menuView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
		[menuView addSubview:menuButton(0, @"Settings", self, @selector(tapped:))];
		[menuView addSubview:menuButton(1, @"Columns", self, @selector(tapped:))];
		[menuView addSubview:menuButton(2, @"Quick Guide", self, @selector(tapped:))];
		[menuView addSubview:menuButton(3, @"About", self, @selector(tapped:))];
		_menuView = menuView;
	}
	return _menuView;
}

- (UIView *)menuTintView
{
	if (_menuTintView == nil) {
		UIView *menuTintView = [[UIView alloc] initWithFrame:CGRectZero];
		menuTintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		menuTintView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
		// Add tap recognizer to dismiss menu when tapping outside its bounds.
		UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openActionSheet)];
		[menuTintView addGestureRecognizer:recognizer];
		[recognizer release];
		_menuTintView = menuTintView;
	}
	return _menuTintView;
}

- (UIView *)menuContainerView
{
	if (_menuContainerView == nil) {
		UIView *menuContainerView = [[UIView alloc] initWithFrame:CGRectZero];
		menuContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		menuContainerView.clipsToBounds = YES;
		[menuContainerView addSubview:self.menuTintView];
		[menuContainerView addSubview:self.menuView];
		_menuContainerView = menuContainerView;
	}
	return _menuContainerView;
}

- (void)layoutMenuContainerView
{
	// NOTE: Access menu container directly (instead of via property) to prevent creation if it does not exist.
	if ([_menuContainerView superview] != nil) {
		CGRect frame = [self.navigationController.view convertRect:self.view.frame fromView:self.view.superview];
		frame.origin.y += self.tableView.contentInset.top;
		frame.size.height -= self.tableView.contentInset.top;
		[_menuContainerView setFrame:frame];
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	[self layoutMenuContainerView];
}

- (IBAction)openActionSheet
{
	UIView *menuContainerView = self.menuContainerView;
	const BOOL willAppear = (menuContainerView.superview == nil);
	if (willAppear) {
		[self.navigationController.view addSubview:menuContainerView];
		[self layoutMenuContainerView];
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

#pragma mark -
#pragma mark View lifecycle

- (IBAction)hideShowNavBar:(UIGestureRecognizer *)gestureRecognizer
{
	if (!gestureRecognizer || gestureRecognizer.state == UIGestureRecognizerStateEnded) {
		self.fullScreen = !self.navigationController.navigationBarHidden;
		// This "scrolls" tableview so that it doesn't actually move when the bars disappear
		if (!self.fullScreen) {			// Show navbar & scrollbar (going out of fullscreen)
			[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
			[self.navigationController setNavigationBarHidden:NO animated:NO];
		}
		CGSize size = [UIApplication sharedApplication].statusBarFrame.size;
		CGFloat slide = MIN(size.width, size.height) +
			self.navigationController.navigationBar.frame.size.height +
			([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] ? self.tableView.sectionHeaderHeight : 0);
		CGPoint contentOffset = self.tableView.contentOffset;
		contentOffset.y += self.fullScreen ? -slide : slide;
		[self.tableView setContentOffset:contentOffset animated:NO];
		if (self.fullScreen) {			// Hide navbar & scrollbar (entering fullscreen)
			[self.navigationController setNavigationBarHidden:YES animated:NO];
			[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
		}
		[self.tableView reloadData];
//		[self.timer fire];
	}
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
	bool isPhone = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;

//	self.wantsFullScreenLayout = YES;

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIButtonBarHamburger"] style:UIBarButtonItemStylePlain
		target:self action:@selector(openActionSheet)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
		target:self action:@selector(refreshProcs:)];
	self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - (isPhone ? 80 : 150), 40)];
	self.status.backgroundColor = [UIColor clearColor];
	self.navigationItem.leftBarButtonItems = @[self.navigationItem.leftBarButtonItem, [[UIBarButtonItem alloc] initWithCustomView:self.status]];

	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideShowNavBar:)];
	twoTap.numberOfTouchesRequired = 2;
	[self.tableView addGestureRecognizer:twoTap];
	[twoTap release];

	self.tableView.sectionHeaderHeight = self.tableView.sectionHeaderHeight * 3 / 2;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
#endif
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		@"Columns" : @[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
		@"UpdateInterval" : @"1",
		@"FullWidthCommandLine" : @NO,
		@"AutoJumpNewProcess" : @NO,
		@"FirstColumnStyle" : @"Bundle Identifier",
		@"ShowHeader" : @YES,
		@"ShowFooter" : @YES,
		@"ShortenPaths" : @YES,
		@"SortColumn" : @1,      @"SortDescending" : @NO,		// Main page (sort by pid)
		@"ProcInfoMode" : @0,
		@"Mode0SortColumn" : @1, @"Mode0SortDescending" : @NO,	// Summary (by initial column order)
		@"Mode1SortColumn" : @0, @"Mode1SortDescending" : @NO,	// Threads (by thread id)
		@"Mode2SortColumn" : @2, @"Mode2SortDescending" : @YES,	// FDs (backwards by type)
		@"Mode3SortColumn" : @1, @"Mode3SortDescending" : @NO,	// Modules (by address)
	}];
	self.configChange = @"";
	self.configId = 0;
	self.selectedPid = -1;
	self.fullScreen = NO;
}

- (void)preRefreshProcs:(NSTimer *)timer
{
	// Time to query network statistics
	[self.procs.nstats query];
	// And update the view when statistics arrive
	if (self.timer.isValid)
		[self.timer invalidate];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:NTSTAT_PREQUERY_INTERVAL target:self selector:@selector(refreshProcs:) userInfo:nil repeats:NO];
}

- (void)refreshProcs:(NSTimer *)timer
{
	// Rearm the timer: this way the timer will wait for a full interval after each 'fire'
	if (self.interval >= 0.1 + NTSTAT_PREQUERY_INTERVAL) {
		if (self.timer.isValid)
			[self.timer invalidate];
		self.timer = [NSTimer scheduledTimerWithTimeInterval:(self.interval - NTSTAT_PREQUERY_INTERVAL) target:self selector:@selector(preRefreshProcs:) userInfo:nil repeats:NO];
	}
	// Do not refresh while the user is killing a process
	if (self.tableView.editing)
		return;
	[self.procs refresh];
	[self.procs sortUsingComparator:self.sorter.sort desc:self.sortdesc];
	[self.tableView reloadData];
	[self.footer updateSummaryWithColumns:self.columns procs:self.procs];
	// Status bar
// Also add: Uptime, CPU Freq, Cores, Cache L1/L2
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
		self.status.text = [NSString stringWithFormat:@"RAM: %.1f MB  CPU: %.1f%%",
			(float)self.procs.memUsed / 1024 / 1024,
			(float)self.procs.totalCpu / 10];
	else
		self.status.text = [NSString stringWithFormat:@"Processes: %u   Threads: %u   RAM: %.1f/%.1f MB   CPU: %.1f%%",
			self.procs.count,
			self.procs.threadCount,
			(float)self.procs.memUsed / 1024 / 1024,
			(float)self.procs.memTotal / 1024 / 1024,
			(float)self.procs.totalCpu / 10];
	// Query network statistics, cause no one did it before.
	if (![timer isKindOfClass:[NSTimer class]])
		[self.procs.nstats query];
	// First time refresh? Or returned from a sub-page.
	if (timer == nil) {
		// We don't need info about new processes, they are all new :)
		[self.procs setAllDisplayed:ProcDisplayNormal];
		NSUInteger idx = NSNotFound;
		if (self.selectedPid != -1) {
			idx = [self.procs indexForPid:self.selectedPid];
			self.selectedPid = -1;
		}
		if (idx != NSNotFound && self.procs[idx].display != ProcDisplayTerminated) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
			[self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] animated:YES];
#endif
		}
	} else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoJumpNewProcess"]) {
		// If there's a new/terminated process, scroll to it
		NSUInteger
			idx = [self.procs indexOfDisplayed:ProcDisplayStarted];
		if (idx == NSNotFound)
			idx = [self.procs indexOfDisplayed:ProcDisplayTerminated];
		if (idx != NSNotFound) {
			// Processes at the end of the list are in priority for scrolling!
			PSProc *last = self.procs[self.procs.count-1];
			if (last.display == ProcDisplayStarted || last.display == ProcDisplayTerminated)
				idx = self.procs.count-1;
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
				atScrollPosition:UITableViewScrollPositionNone animated:YES];
		}
		// [self.tableView insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
		// [self.tableView deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	}
}

- (void)sortHeader:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint loc = [gestureRecognizer locationInView:self.header];
	for (PSColumn *col in self.columns) {
		if (loc.x > col.width) {
			loc.x -= col.width;
			continue;
		}
		self.sortdesc = self.sorter == col ? !self.sortdesc : col.sortDesc;
		[self.header sortColumnOld:self.sorter New:col desc:self.sortdesc];
		self.sorter = col;
		[[NSUserDefaults standardUserDefaults] setInteger:col.tag-1 forKey:@"SortColumn"];
		[[NSUserDefaults standardUserDefaults] setBool:self.sortdesc forKey:@"SortDescending"];
		[self.timer fire];
		break;
	}
}

- (void)scrollToBottom
{
	[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0]-1 inSection:0]
		atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	// When major options change, process list is rebuilt from scratch
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	NSString *configCheck = [NSString stringWithFormat:@"%d-%@", [def boolForKey:@"ShortenPaths"], [def stringForKey:@"FirstColumnStyle"]];
	if (![self.configChange isEqualToString:configCheck]) {
		self.procs = [PSProcArray psProcArrayWithIconSize:self.tableView.rowHeight];
		self.configChange = configCheck;
	}
	// When configId changes, all cells are reconfigured
	self.configId++;
	self.columns = [PSColumn psGetShownColumnsWithWidth:self.tableView.bounds.size.width];
	// Find sort column and create table header
	NSUInteger sortCol = [[NSUserDefaults standardUserDefaults] integerForKey:@"SortColumn"];
	NSArray *allColumns = [PSColumn psGetAllColumns];
	if (sortCol >= allColumns.count) sortCol = 1;
	self.sorter = allColumns[sortCol];
	self.sortdesc = [[NSUserDefaults standardUserDefaults] boolForKey:@"SortDescending"];
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionHeaderHeight)];
	self.footer = [GridHeaderView footerWithColumns:self.columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionFooterHeight)];
	[self.header sortColumnOld:nil New:self.sorter desc:self.sortdesc];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
	[self.footer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollToBottom)]];
	// Refresh interval
	self.interval = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	[self refreshProcs:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	if (self.timer.isValid)
		[self.timer invalidate];

	if (_menuContainerView != nil) {
		[_menuContainerView removeFromSuperview];
		[_menuContainerView release];
		_menuContainerView = nil;
		[_menuTintView release];
		_menuTintView = nil;
		[_menuView release];
		_menuView = nil;
	}

	self.header = nil;
	self.columns = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if ((fromInterfaceOrientation == UIInterfaceOrientationPortrait || fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) &&
		(self.interfaceOrientation == UIInterfaceOrientationPortrait || self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
		return;
	if ((fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight) &&
		(self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft || self.interfaceOrientation == UIInterfaceOrientationLandscapeRight))
		return;
	// Size changed - need to redraw
	self.configId++;
	self.columns = [PSColumn psGetShownColumnsWithWidth:self.tableView.bounds.size.width];
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionHeaderHeight)];
	self.footer = [GridHeaderView footerWithColumns:self.columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionFooterHeight)];
	[self.header sortColumnOld:nil New:self.sorter desc:self.sortdesc];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
	[self.footer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollToBottom)]];
	[self.timer fire];
}

#pragma mark -
#pragma mark Table view data source

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Section header/footer will be used as a grid header/footer
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] && !self.fullScreen ? self.header : nil; }

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFooter"] && !self.fullScreen ? self.footer : nil; }

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] && !self.fullScreen ? self.tableView.sectionHeaderHeight : 0; }

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFooter"] && !self.fullScreen ? self.tableView.sectionFooterHeight : 0; }

// Data is acquired from PSProcArray
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.procs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSProc *proc = nil;
	if (indexPath.row >= self.procs.count) {
		NSLog(@"*** cellForRowAtIndexPath requested row %d of %d", indexPath.row, self.procs.count);
//		return [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:NO]];
	} else if (!self.columns || !self.columns.count) {
		NSLog(@"*** cellForRowAtIndexPath requested row %d with empty columns", indexPath.row);
//		return [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:NO]];
	} else
		proc = self.procs[indexPath.row];
	GridTableCell *cell = [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:proc.icon != nil]];
	if (cell == nil)
		cell = [GridTableCell cellWithIcon:proc.icon != nil];
	[cell configureWithId:self.configId columns:self.columns size:CGSizeMake(0, tableView.rowHeight)];
	if (proc != nil)
		[cell updateWithProc:proc columns:self.columns];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	display_t display = self.procs[indexPath.row].display;
	if (display == ProcDisplayTerminated)
		cell.backgroundColor = [UIColor colorWithRed:1 green:0.7 blue:0.7 alpha:1];
	else if (display == ProcDisplayStarted)
		cell.backgroundColor = [UIColor colorWithRed:0.7 green:1 blue:0.7 alpha:1];
	else if (indexPath.row & 1)
		cell.backgroundColor = [UIColor colorWithRed:.95 green:.95 blue:.95 alpha:1];
	else
		cell.backgroundColor = [UIColor whiteColor];
}

- (void)tableView:(UITableView *)tableView sendSignal:(int)sig toProcessAtIndexPath:(NSIndexPath *)indexPath
{
	PSProc *proc = self.procs[indexPath.row];
	// task_for_pid(mach_task_self(), pid, &task)
	// task_terminate(task)
	if (kill(proc.pid, sig)) {
		NSString *msg = [NSString stringWithFormat:@"Error %d while terminating app", errno];
		UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:proc.name message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[alertView show];
	}
	// Refresh immediately to show process termination
	tableView.editing = NO;
	[self.timer performSelector:@selector(fire) withObject:nil afterDelay:.1f];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"TERM";
}

- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"KILL";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
		[self tableView:tableView sendSignal:SIGTERM toProcessAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self tableView:tableView sendSignal:SIGKILL toProcessAtIndexPath:indexPath];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	BOOL anim = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	// Shitty bug in iOS 7
	if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_8_0) anim = YES;
#endif
	// Return from fullscreen, or there's no way back ;)
	if (self.fullScreen)
		[self hideShowNavBar:nil];
	PSProc *proc = self.procs[indexPath.row];
	self.selectedPid = proc.pid;
	SockViewController* sockViewController = [[SockViewController alloc] initWithProc:proc];
		[self.navigationController pushViewController:sockViewController animated:anim];
		[sockViewController release];
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	NSLog(@"didReceiveMemoryWarning");
	// Relinquish ownership of any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	if (self.timer.isValid)
		[self.timer invalidate];
	self.status = nil;
	self.header = nil;
	self.footer = nil;
	self.sorter = nil;
	self.procs = nil;
	self.columns = nil;
}

- (void)dealloc
{
	if (self.timer.isValid)
		[self.timer invalidate];
	[_timer release];
	[_status release];
	[_header release];
	[_footer release];
	[_sorter release];
	[_procs release];
	[_columns release];
	[_menuContainerView release];
	[_menuTintView release];
	[_menuView release];
	[super dealloc];
}

@end
