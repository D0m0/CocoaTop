#import "SockViewController.h"
#import "GridCell.h"
#import "Column.h"
#import "Sock.h"

NSString *ColumnModeName[ColumnModes] = {@"Summary", @"Threads", @"Open files", @"Modules"};

@interface SockViewController()
@property (retain) PSProc *proc;
@property (retain) NSString *name;
@property (retain) GridHeaderView *header;
@property (retain) NSArray *columns;
@property (retain) NSTimer *timer;
@property (retain) PSSockArray *socks;
@property (retain) PSColumn *sorter;
@property (assign) BOOL sortdesc;
@property (assign) BOOL fullScreen;
@property (assign) CGFloat interval;
@property (assign) NSUInteger configId;
@property (retain) UISegmentedControl *modeSelector;
@property (assign) column_mode_t mode;
@end

@implementation SockViewController

#pragma mark -
#pragma mark View lifecycle

- (instancetype)initWithProc:(PSProc *)proc
{
	self = [super init];
	self.proc = proc;
	return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
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

- (IBAction)modeChange:(UISegmentedControl *)modeSelector
{
	// Mode changed - need to reset all information
	self.socks = [PSSockArray psSockArrayWithProc:self.proc];
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		self.mode = ColumnNextMode(self.mode);
		[modeSelector setTitle:ColumnModeName[ColumnNextMode(self.mode)] forSegmentAtIndex:0];
	} else
		self.mode = modeSelector.selectedSegmentIndex;
	[self configureMode];
	[[NSUserDefaults standardUserDefaults] setInteger:self.mode forKey:@"ProcInfoMode"];
	[self refreshSocks:nil];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Back"
		style: UIBarButtonItemStyleDone target:self action:@selector(backWithoutAnimation)];
	self.navigationItem.leftBarButtonItem = item;
	[item release];

	self.mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"ProcInfoMode"];
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		self.modeSelector = [[UISegmentedControl alloc] initWithItems:@[ColumnModeName[ColumnNextMode(self.mode)]]];
		self.modeSelector.momentary = YES;
	} else {
		self.modeSelector = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:ColumnModeName count:ColumnModes]];
		self.modeSelector.selectedSegmentIndex = self.mode;
	}
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_6_0
	CGRect frame = self.modeSelector.frame;
		frame.size.height = self.navigationController.navigationBar.frame.size.height * 2 / 3;
		self.modeSelector.frame = frame;
#endif
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.modeSelector];
	[self.modeSelector addTarget:self action:@selector(modeChange:) forControlEvents:UIControlEventValueChanged];

	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideShowNavBar:)];
	twoTap.numberOfTouchesRequired = 2;
	[self.tableView addGestureRecognizer:twoTap]; [twoTap release];

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
	[self.socks refreshWithMode:self.mode];
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
		self.sortdesc = self.sorter == col ? !self.sortdesc : col.sortDesc;
		[self.header sortColumnOld:self.sorter New:col desc:self.sortdesc];
		self.sorter = col;
		[[NSUserDefaults standardUserDefaults] setInteger:col.tag-1 forKey:[NSString stringWithFormat:@"Mode%dSortColumn", self.mode]];
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
	NSUInteger sortCol = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"Mode%dSortColumn", self.mode]];
	NSArray *allColumns = [PSColumn psGetTaskColumns:self.mode];
	if (sortCol >= allColumns.count) sortCol = 1;
	self.sorter = allColumns[sortCol];
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
	[super viewWillDisappear:animated];
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
		   *message = (self.mode == ColumnModeSummary) ? sock.col.getData(sock.proc) : sock.name;
	UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	[alertView show];
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
	self.header = nil;
	self.sorter = nil;
	self.socks = nil;
	self.columns = nil;
}

- (void)dealloc
{
	if (self.timer.isValid)
		[self.timer invalidate];
	[_timer release];
	[_sorter release];
	[_socks release];
	[_columns release];
	[super dealloc];
}

@end
