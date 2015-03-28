#import "SockViewController.h"
#import "GridCell.h"
#import "Column.h"
#import "Sock.h"

@interface SockViewController()
@property (retain) NSString *name;
@property (assign) pid_t pid;
@property (assign) NSUInteger firstColWidth;
@property (retain) GridHeaderView *header;
@property (retain) NSArray *columns;
@property (retain) NSTimer *timer;
@property (retain) PSSockArray *socks;
@property (retain) PSColumn *sorter;
@property (assign) BOOL sortdesc;
@property (assign) BOOL fullScreen;
@property (assign) CGFloat interval;
@property (assign) NSUInteger configId;
@end

@implementation SockViewController

#pragma mark -
#pragma mark View lifecycle

- (instancetype)initWithName:(NSString *)name pid:(pid_t)pid
{
	self = [super init];
	self.name = name;
	self.pid = pid;
	return self;
}

- (void)backWithoutAnimation
{
	[self.navigationController popViewControllerAnimated:NO];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"\u276C Back"
		style: UIBarButtonItemStyleDone target:self action:@selector(backWithoutAnimation)];
	self.navigationItem.leftBarButtonItem = item;
	[item release];
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
	[self.socks refresh];
	[self.socks sortUsingComparator:self.sorter.sort desc:self.sortdesc];
	[self.tableView reloadData];
	// First time refresh?
	if (timer == nil) {
		// We don't need info about new sockets, they are all new :)
		[self.socks setAllDisplayed:ProcDisplayNormal];
	} else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoJumpNewProcess"]) {
		// If there's a new socket, scroll to it
		NSUInteger idx = [self.socks indexOfDisplayed:ProcDisplayStarted];
		if (idx != NSNotFound)
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
				atScrollPosition:UITableViewScrollPositionNone animated:YES];
	}
}

- (void)sortHeader:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint loc = [gestureRecognizer locationInView:self.header];
	for (PSColumn *col in self.columns) {
		NSUInteger width = col.tag == 1 ? self.firstColWidth : col.width;
		if (loc.x > width) {
			loc.x -= width;
			continue;
		}
		self.sortdesc = self.sorter == col ? !self.sortdesc : NO;
		[self.header sortColumnOld:self.sorter New:col desc:self.sortdesc];
		self.sorter = col;
		[[NSUserDefaults standardUserDefaults] setInteger:col.tag-1 forKey:@"SockSortColumn"];
		[[NSUserDefaults standardUserDefaults] setBool:self.sortdesc forKey:@"SockSortDescending"];
		[self.timer fire];
		break;
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationItem.title = self.name;
	self.socks = [PSSockArray psSockArrayWithPid:self.pid];
	// When configId changes, all cells are reconfigured
	self.configId++;
	self.firstColWidth = self.tableView.bounds.size.width;
	self.columns = [PSColumn psGetOpenFilesColumnsWithWidth:&_firstColWidth];
	// Find sort column and create table header
	NSUInteger sortCol = [[NSUserDefaults standardUserDefaults] integerForKey:@"SockSortColumn"];
	if (sortCol >= self.columns.count) sortCol = 2;
	self.sorter = self.columns[sortCol];
	self.sortdesc = [[NSUserDefaults standardUserDefaults] boolForKey:@"SockSortDescending"];
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(self.firstColWidth, self.tableView.sectionHeaderHeight)];
	[self.header sortColumnOld:nil New:self.sorter desc:self.sortdesc];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
	// Refresh interval
	self.interval = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	[self refreshSocks:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	if (self.timer.isValid)
		[self.timer invalidate];
	self.header = nil;
	self.columns = nil;
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
	self.firstColWidth = self.tableView.bounds.size.width;
	self.columns = [PSColumn psGetOpenFilesColumnsWithWidth:&_firstColWidth];
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(self.firstColWidth, self.tableView.sectionHeaderHeight)];
	[self.header sortColumnOld:nil New:self.sorter desc:self.sortdesc];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
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
	[cell configureWithId:self.configId columns:self.columns size:CGSizeMake(self.firstColWidth, tableView.rowHeight)];
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
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (cell) {
		UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:@"Open file/socket" message:cell.textLabel.text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[alertView show];
	}
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
