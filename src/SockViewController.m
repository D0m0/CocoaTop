#import "Compat.h"
#import "SockViewController.h"
#import "GridCell.h"
#import "Column.h"
#import "Sock.h"

NSString *ColumnModeName[ColumnModes] = {@"Summary", @"Threads", @"Open files", @"Modules"};

@interface SockViewController()
@property (strong) PSProc *proc;
@property (strong) NSString *name;
@property (strong) GridHeaderView *header;
@property (strong) NSArray *columns;
@property (strong) NSTimer *timer;
@property (strong) PSSockArray *socks;
@property (strong) PSColumn *sorter;
@property (assign) BOOL sortdesc;
@property (assign) BOOL fullScreen;
@property (assign) CGFloat interval;
@property (assign) NSUInteger configId;
@property (assign) column_mode_t mode;
@end

@implementation SockViewController

- (void)popupMenuTappedItem:(NSInteger)item
{
	if (self.mode != item) {
		// Mode changed - need to reset all information
		self.mode = self.popupMenuSelected = item;
		self.socks = [PSSockArray psSockArrayWithProc:self.proc];
		[self configureMode];
		[[NSUserDefaults standardUserDefaults] setInteger:self.mode forKey:@"ProcInfoMode"];
		[self refreshSocks:nil];
	}
}

- (instancetype)initWithProc:(PSProc *)proc
{
	self = [super init];
	self.proc = proc;
	return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (IBAction)backWithoutAnimation
{
	[self.navigationController popViewControllerAnimated:NO];
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

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
		style: UIBarButtonItemStyleDone target:self action:@selector(backWithoutAnimation)];

	self.mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"ProcInfoMode"];
	[self popupMenuWithItems:[NSArray arrayWithObjects:ColumnModeName count:ColumnModes] selected:self.mode aligned:UIControlContentHorizontalAlignmentRight];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIButtonBarHamburger"] style:UIBarButtonItemStylePlain
		target:self action:@selector(popupMenuToggle)];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
#endif
	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideShowNavBar:)];
	twoTap.numberOfTouchesRequired = 2;
	[self.tableView addGestureRecognizer:twoTap];

	self.tableView.sectionHeaderHeight = self.tableView.sectionHeaderHeight * 3 / 2;
	self.tableView.rowHeight = self.tableView.rowHeight * 2 / 3;
	self.configId = 0;
	self.fullScreen = NO;
}

- (void)refreshSocks:(NSTimer *)timer
{
	// Rearm the timer: this way the timer will wait for a full interval after each 'fire'
	if (self.interval >= 0.1) {
		if (self.timer.isValid)
			[self.timer invalidate];
		self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval target:self selector:@selector(refreshSocks:) userInfo:nil repeats:NO];
	}
	// Update titlebar
	[self.proc update];
	self.navigationItem.title = [self.name stringByAppendingFormat:@" (CPU %.1f%%)", (float)self.proc.pcpu / 10];
	// Update tableview
	if ([self.socks refreshWithMode:self.mode])
		self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:1 green:0.7 blue:0.7 alpha:1];
	[self.socks sortUsingComparator:self.sorter.sort desc:self.sortdesc];
	[self.tableView reloadData];
	// First time refresh?
	if (timer == nil) {
		// We don't need info about new sockets, they are all new :)
		[self.socks setAllDisplayed:ProcDisplayNormal];
		// When mode changes return to top
		if (self.socks.count)
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
				atScrollPosition:UITableViewScrollPositionNone animated:NO];
	} else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoJumpNewProcess"]) {
		// If there's a new socket, scroll to it
		NSUInteger
			idx = [self.socks indexOfDisplayed:ProcDisplayStarted];
		if (idx == NSNotFound)
			idx = [self.socks indexOfDisplayed:ProcDisplayTerminated];
		if (idx != NSNotFound)
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
				atScrollPosition:UITableViewScrollPositionNone animated:YES];
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
		[[NSUserDefaults standardUserDefaults] setInteger:col.tag forKey:[NSString stringWithFormat:@"Mode%dSortColumn", self.mode]];
		[[NSUserDefaults standardUserDefaults] setBool:self.sortdesc forKey:[NSString stringWithFormat:@"Mode%dSortDescending", self.mode]];
		[self.timer fire];
		break;
	}
}

- (void)configureMode
{
	// When configId changes, all cells are reconfigured
	self.configId++;
	self.columns = [PSColumn psGetTaskColumnsWithWidth:self.tableView.bounds.size.width mode:self.mode];
	// Find sort column and create table header
	NSString *key = [NSString stringWithFormat:@"Mode%dSortColumn", self.mode];
	self.sorter = [PSColumn psTaskColumnWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:key] forMode:self.mode];
	if (!self.sorter) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
		self.sorter = [PSColumn psTaskColumnWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:key] forMode:self.mode];
		if (!self.sorter) self.sorter = self.columns[0];
	}
	self.sortdesc = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"Mode%dSortDescending", self.mode]];
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(0, self.tableView.sectionHeaderHeight)];
	[self.header sortColumnOld:nil New:self.sorter desc:self.sortdesc];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.socks = [PSSockArray psSockArrayWithProc:self.proc];
	self.name = [self.proc.executable lastPathComponent];
	[self configureMode];
	// Refresh interval
	self.interval = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	[self refreshSocks:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	if (self.timer.isValid)
		[self.timer invalidate];
	self.socks = nil;
	self.header = nil;
	self.columns = nil;
	self.proc = nil;
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
	[self configureMode];
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
{ return !self.fullScreen ? self.header : nil; }

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{ return !self.fullScreen ? self.tableView.sectionHeaderHeight : 0; }

// Data is acquired from PSProcArray
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.socks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row >= self.socks.count)
		return nil;
	PSSock *sock = self.socks[indexPath.row];
	GridTableCell *cell = [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:NO]];
	if (cell == nil)
		cell = [GridTableCell cellWithIcon:NO];
	[cell configureWithId:self.configId columns:self.columns size:CGSizeMake(0, tableView.rowHeight)];
	[cell updateWithSock:sock columns:self.columns];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	display_t display = self.socks[indexPath.row].display;
	if (display == ProcDisplayTerminated)
		cell.backgroundColor = [UIColor colorWithRed:1 green:0.7 blue:0.7 alpha:1];
	else if (display == ProcDisplayStarted)
		cell.backgroundColor = [UIColor colorWithRed:0.7 green:1 blue:0.7 alpha:1];
	else if (indexPath.row & 1)
		cell.backgroundColor = [UIColor colorWithRed:.95 green:.95 blue:.95 alpha:1];
	else
		cell.backgroundColor = [UIColor whiteColor];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSSockSummary *sock = (PSSockSummary *)self.socks[indexPath.row];
	if (!sock)
		return;
	NSString *title = (self.mode == ColumnModeSummary) ? sock.name : @"Property",
		   *message = (self.mode == ColumnModeSummary) ? [NSString stringWithFormat:@"%@\n\n%@", sock.col.getData(sock.proc),
		   [sock.col.descr substringWithRange:[sock.col.descr lineRangeForRange:NSMakeRange(0,1)]]] : sock.name;
	[[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

#pragma mark -
#pragma mark Memory management

- (void)viewDidUnload
{
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	if (self.timer.isValid)
		[self.timer invalidate];
	self.header = nil;
	self.sorter = nil;
	self.socks = nil;
	self.columns = nil;
	[super viewDidUnload];
}

- (void)dealloc
{
	if (self.timer.isValid)
		[self.timer invalidate];
}

@end
