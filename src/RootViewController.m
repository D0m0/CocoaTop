#import "Compat.h"
#import "RootViewController.h"
#import "SockViewController.h"
#import "THtmlViewController.h"
#import "Setup.h"
#import "SetupColumns.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"
#import "ProcArray.h"

#define NTSTAT_PREQUERY_INTERVAL	0.1

@interface RootViewController()
@property (strong) GridHeaderView *header;
@property (strong) GridHeaderView *footer;
@property (strong) PSProcArray *procs;
@property (strong) NSTimer *timer;
@property (strong) UILabel *status;
@property (strong) NSArray *columns;
@property (strong) PSColumn *sorter;
@property (assign) BOOL sortdesc;
@property (assign) BOOL fullScreen;
@property (assign) CGFloat interval;
@property (assign) NSUInteger configId;
@property (strong) NSString *configChange;
@property (assign) pid_t selectedPid;
@end

@implementation RootViewController

- (void)popupMenuTappedItem:(NSInteger)item
{
	UIViewController* view = nil;
	switch (item) {
	case 0: view = [[SetupViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	case 1: view = [[SetupColsViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	case 2: view = [[HtmlViewController alloc] initWithURL:@"guide" title:@"Quick Guide"]; break;
	case 3: view = [[HtmlViewController alloc] initWithURL:@"story" title:@"The Story"]; break;
	}
	if (view)
		[self.navigationController pushViewController:view animated:YES];
}

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
	[self popupMenuWithItems:@[@"Settings", @"Columns", @"Quick Guide", @"About"] selected:-1 aligned:UIControlContentHorizontalAlignmentLeft];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIButtonBarHamburger"] style:UIBarButtonItemStylePlain
		target:self action:@selector(popupMenuToggle)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
		target:self action:@selector(refreshProcs:)];
	self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - (isPhone ? 80 : 150), 40)];
	self.status.backgroundColor = [UIColor clearColor];
	self.navigationItem.leftBarButtonItems = @[self.navigationItem.leftBarButtonItem, [[UIBarButtonItem alloc] initWithCustomView:self.status]];

	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideShowNavBar:)];
	twoTap.numberOfTouchesRequired = 2;
	[self.tableView addGestureRecognizer:twoTap];

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
		@"SortColumn" : @1,         @"SortDescending" : @NO,		// Main page (sort by pid)
		@"ProcInfoMode" : @0,
		@"Mode0SortColumn" : @1001, @"Mode0SortDescending" : @NO,	// Summary (by initial column order)
		@"Mode1SortColumn" : @2000, @"Mode1SortDescending" : @NO,	// Threads (by thread id)
		@"Mode2SortColumn" : @3002, @"Mode2SortDescending" : @YES,	// FDs (backwards by type)
		@"Mode3SortColumn" : @4001, @"Mode3SortDescending" : @NO,	// Modules (by address)
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
		self.sortdesc = self.sorter == col ? !self.sortdesc : col.style & ColumnStyleSortDesc;
		[self.header sortColumnOld:self.sorter New:col desc:self.sortdesc];
		self.sorter = col;
		[[NSUserDefaults standardUserDefaults] setInteger:col.tag forKey:@"SortColumn"];
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
	self.sorter = [PSColumn psColumnWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"SortColumn"]];
	if (!self.sorter) self.sorter = self.columns[0];
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
	if (cell == nil)
		NSLog(@"*** cellForRowAtIndexPath requested row %d, cell = nil", indexPath.row);
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
		[[[UIAlertView alloc] initWithTitle:proc.name message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
	}
	// Refresh immediately to show process termination
	tableView.editing = NO;
	[self.timer performSelector:@selector(fire) withObject:nil afterDelay:.1f];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"KILL";
}

- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"TERM";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
		[self tableView:tableView sendSignal:SIGKILL toProcessAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self tableView:tableView sendSignal:SIGTERM toProcessAtIndexPath:indexPath];
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
	[self.navigationController pushViewController:[[SockViewController alloc] initWithProc:proc] animated:anim];
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	NSLog(@"didReceiveMemoryWarning");
}

- (void)viewDidUnload
{
	if (self.timer.isValid)
		[self.timer invalidate];
	self.status = nil;
	self.header = nil;
	self.footer = nil;
	self.sorter = nil;
	self.procs = nil;
	self.columns = nil;
	[super viewDidUnload];
}

- (void)dealloc
{
	if (self.timer.isValid)
		[self.timer invalidate];
}

@end
