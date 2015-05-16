#import "RootViewController.h"
#import "SockViewController.h"
#import "Setup.h"
#import "SetupColumns.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"
#import <sys/ioctl.h>
#import <sys/socket.h>
#import "sys/kern_control.h"
#import "sys/sys_domain.h"
#define PRIVATE
#import "net/ntstat.h"

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
@property (assign) CFSocketRef netStat;
@end

@implementation RootViewController

#pragma mark -
#pragma mark View lifecycle

- (IBAction)openSettings
{
	SetupViewController* setupViewController = [[SetupViewController alloc] initWithStyle:UITableViewStyleGrouped];
	[self.navigationController pushViewController:setupViewController animated:YES];
	[setupViewController release];
}

- (IBAction)openColSettings
{
	SetupColsViewController* setupColsViewController = [[SetupColsViewController alloc] initWithStyle:UITableViewStyleGrouped];
	[self.navigationController pushViewController:setupColsViewController animated:YES];
	[setupColsViewController release];
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
		[self.timer fire];
	}
}

int addAll(int fd, int provider)
{
	nstat_msg_add_all_srcs aasreq;
	aasreq.provider = provider;
	aasreq.hdr.type = NSTAT_MSG_TYPE_ADD_ALL_SRCS;
	aasreq.hdr.context = 3;						// Some shit
	return write(fd, &aasreq, sizeof(aasreq));
}

int queryAllSrc(int fd)
{
	nstat_msg_query_src_req qsreq;
	qsreq.hdr.type = NSTAT_MSG_TYPE_QUERY_SRC;
	qsreq.srcref = NSTAT_SRC_REF_ALL;
	qsreq.hdr.context = 1005;					// This way I can tell if errors get returned for dead sources
	return write(fd, &qsreq, sizeof(qsreq));
}

int refreshSrc(int fd, int Prov, int Num)
{
	nstat_msg_get_src_description gsdreq;
	gsdreq.hdr.type = NSTAT_MSG_TYPE_GET_SRC_DESC;
	gsdreq.srcref = Num;
	gsdreq.hdr.context = Prov;
	return write(fd, &gsdreq, sizeof(gsdreq));
}

void NetStatCallBack(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
//	RootViewController *self = (RootViewController *)info;
	nstat_msg_hdr *ns = (nstat_msg_hdr *)CFDataGetBytePtr((CFDataRef)data);
	int len = CFDataGetLength((CFDataRef)data);

	if (!len)
		NSLog(@"NSTAT type:%lu, datasize:0", callbackType);
	else
	switch (ns->type) {
	case NSTAT_MSG_TYPE_SRC_ADDED:		NSLog(@"NSTAT_MSG_TYPE_SRC_ADDED, size:%d", len); /*refreshSrc(int fd, int Prov, int Num);*/ break;
	case NSTAT_MSG_TYPE_SRC_REMOVED:	NSLog(@"NSTAT_MSG_TYPE_SRC_REMOVED, size:%d", len); break;
	case NSTAT_MSG_TYPE_SRC_DESC:		NSLog(@"NSTAT_MSG_TYPE_SRC_DESC, size:%d", len); break;
	case NSTAT_MSG_TYPE_SRC_COUNTS:		NSLog(@"NSTAT_MSG_TYPE_SRC_COUNTS, size:%d", len); break;
	case NSTAT_MSG_TYPE_SUCCESS:		NSLog(@"NSTAT_MSG_TYPE_SUCCESS, size:%d", len); break;
	case NSTAT_MSG_TYPE_ERROR:			NSLog(@"NSTAT_MSG_TYPE_ERROR, size:%d", len); break;
	default:							NSLog(@"NSTAT:%d, size:%d", ns->type, len); break;
	}
	// For each NSTAT_MSG_TYPE_SRC_ADDED:
	// NSTAT_MSG_TYPE_GET_SRC_DESC, srcref...
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
	bool isPhone = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;

	UIBarButtonItem *setupButton = [[UIBarButtonItem alloc] initWithTitle: isPhone ? @"\u2699" : @"Settings"
		style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
	UIBarButtonItem *setupColsButton;
	if (isPhone)
		setupColsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
			target:self action:@selector(openColSettings)];
	else
		setupColsButton = [[UIBarButtonItem alloc] initWithTitle: /*isPhone ? @"\u25EB" :*/ @"Columns"
			style:UIBarButtonItemStylePlain target:self action:@selector(openColSettings)];
	if (isPhone) {
		NSDictionary *font = [NSDictionary dictionaryWithObject:[UIFont systemFontOfSize:25.0] forKey:NSFontAttributeName];
		[setupButton setTitleTextAttributes:font forState:UIControlStateNormal];
		[setupColsButton setTitleTextAttributes:font forState:UIControlStateNormal];
	}
	self.navigationItem.rightBarButtonItems = @[setupButton, setupColsButton];
	[setupButton release];
	[setupColsButton release];

	self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - (isPhone ? 80 : 150), 40)];
	self.status.backgroundColor = [UIColor clearColor];
	self.status.userInteractionEnabled = YES;
	[self.status addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(refreshProcs:)]];
	UIBarButtonItem *cpuLoad = [[UIBarButtonItem alloc] initWithCustomView:self.status];
	self.navigationItem.leftBarButtonItem = cpuLoad;
	[cpuLoad release];

	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideShowNavBar:)];
	twoTap.numberOfTouchesRequired = 2;
	[self.tableView addGestureRecognizer:twoTap]; [twoTap release];

	self.tableView.sectionHeaderHeight = self.tableView.sectionHeaderHeight * 3 / 2;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
#endif
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		@"Columns" : @[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
		@"UpdateInterval" : @"1",
		@"FullWidthCommandLine" : @NO,
		@"AutoJumpNewProcess" : @NO,
		@"UseAppleIconApi" : @NO,
		@"CpuGraph" : @NO,
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

//	kCFSocketReadCallBack
	CFSocketContext ctx = {0, self, 0, 0, 0};
	self.netStat = CFSocketCreate(0, PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL, kCFSocketDataCallBack, NetStatCallBack, &ctx);
	CFRunLoopAddSource(
		[[NSRunLoop currentRunLoop] getCFRunLoop],
		CFSocketCreateRunLoopSource(0, self.netStat, 0/*order*/),
		kCFRunLoopCommonModes);
	struct ctl_info ctlInfo = {0, NET_STAT_CONTROL_NAME};
	int fd = CFSocketGetNative(self.netStat);
	if (ioctl(fd, CTLIOCGINFO, &ctlInfo) == -1) {
		NSLog(@"ioctl failed");
		CFSocketInvalidate(self.netStat);
		CFRelease(self.netStat);
		self.netStat = 0;
		return;
	}
	struct sockaddr_ctl sc = {sizeof(sc), AF_SYSTEM, AF_SYS_CONTROL, ctlInfo.ctl_id, 0};
	CFDataRef addr = CFDataCreate(0, (const UInt8 *)&sc, sizeof(sc));
	// Make a connect-callback, then do addAll/queryAllSrc in the callback???
	CFSocketError err = CFSocketConnectToAddress(self.netStat, addr, .1);
	if (err != kCFSocketSuccess) {
		NSLog(@"CFSocketConnectToAddress err=%ld", err);
		CFSocketInvalidate(self.netStat);
		CFRelease(self.netStat);
		self.netStat = 0;
		return;
	}
	addAll(fd, NSTAT_PROVIDER_TCP);
	addAll(fd, NSTAT_PROVIDER_UDP);
	queryAllSrc(fd);
}

- (void)refreshProcs:(NSTimer *)timer
{
	// Rearm the timer: this way the timer will wait for a full interval after each 'fire'
	if (self.interval >= 0.1) {
		if (self.timer.isValid)
			[self.timer invalidate];
		self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval target:self selector:@selector(refreshProcs:) userInfo:nil repeats:NO];
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
		self.status.text = [NSString stringWithFormat:@"\u2699 Processes: %u   Threads: %u   RAM: %.1f/%.1f MB   CPU: %.1f%%",
			self.procs.count,
			self.procs.threadCount,
			(float)self.procs.memUsed / 1024 / 1024,
			(float)self.procs.memTotal / 1024 / 1024,
			(float)self.procs.totalCpu / 10];
	// First time refresh?
	if (timer == nil) {
		// We don't need info about new processes, they are all new :)
		[self.procs setAllDisplayed:ProcDisplayNormal];
		NSUInteger idx = NSNotFound;
		if (self.selectedPid != -1)
			idx = [self.procs indexForPid:self.selectedPid];
		if (idx != NSNotFound && self.procs[idx].display != ProcDisplayTerminated) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
			[self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] animated:YES];
#endif
			self.selectedPid = -1;
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
	NSString *configCheck = [NSString stringWithFormat:@"%d-%d-%@", [def boolForKey:@"UseAppleIconApi"], [def boolForKey:@"ShortenPaths"], [def stringForKey:@"FirstColumnStyle"]];
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
	self.header = nil;
	self.columns = nil;

	CFSocketInvalidate(self.netStat);
	CFRelease(self.netStat);
	self.netStat = 0;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
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
	if (indexPath.row >= self.procs.count) {
		NSLog(@"*** cellForRowAtIndexPath requested row %d of %d", indexPath.row, self.procs.count);
		return [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:NO]];
	}
	if (!self.columns || !self.columns.count) {
		NSLog(@"*** cellForRowAtIndexPath requested row %d with empty columns", indexPath.row);
		return [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:NO]];
	}
	PSProc *proc = self.procs[indexPath.row];
	GridTableCell *cell = [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:proc.icon != nil]];
	if (cell == nil)
		cell = [GridTableCell cellWithIcon:proc.icon != nil];
	[cell configureWithId:self.configId columns:self.columns size:CGSizeMake(0, tableView.rowHeight)];
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
	if (floor(NSFoundationVersionNumber) <= 1134.0) anim = YES; //NSFoundationVersionNumber_iOS_8_0
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
	[super dealloc];
}

@end
