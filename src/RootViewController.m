#import "RootViewController.h"
#import "Setup.h"
#import "SetupColumns.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"

@interface RootViewController()
@property (assign) NSUInteger firstColWidth;
@property (assign) NSInteger colState;
@property (retain) GridHeaderView *header;
@property (retain) NSArray *columns;
@property (retain) NSTimer *timer;
@property (retain) PSProcArray *procs;
@property (retain) PSColumn *sorter;
@property (retain) UILabel *status;
@property (assign) BOOL sortdesc;
@property (assign) CGFloat interval;
@property (retain) NSString *majorOptions;
@end

@implementation RootViewController

#pragma mark -
#pragma mark View lifecycle

- (void)openSettings
{
	SetupViewController* setupViewController = [[SetupViewController alloc] initWithStyle:UITableViewStyleGrouped];
	[self.navigationController pushViewController:setupViewController animated:YES];
	[setupViewController release];
}

- (void)openColSettings
{
	SetupColsViewController* setupColsViewController = [[SetupColsViewController alloc] initWithStyle:UITableViewStyleGrouped];
	[self.navigationController pushViewController:setupColsViewController animated:YES];
	[setupColsViewController release];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
//	'GEAR' (\u2699)		'GEAR WITHOUT HUB' (\u26ED)
	UIBarButtonItem *setupButton = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStylePlain
		target:self action:@selector(openSettings)];
	UIBarButtonItem *setupColsButton = [[UIBarButtonItem alloc] initWithTitle:@"Columns" style:UIBarButtonItemStylePlain
		target:self action:@selector(openColSettings)];
	self.navigationItem.rightBarButtonItems = @[setupButton, setupColsButton];
	[setupButton release];
	[setupColsButton release];

	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
		self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - 80, 40)];
	else
		self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - 150, 40)];
	self.status.backgroundColor = [UIColor clearColor];
	self.status.userInteractionEnabled = YES;
	[self.status addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(refreshProcs)]];
	UIBarButtonItem *cpuLoad = [[UIBarButtonItem alloc] initWithCustomView:self.status];
	self.navigationItem.leftBarButtonItem = cpuLoad;
	[cpuLoad release];

	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	self.majorOptions = [NSString stringWithFormat:@"%d-%@", [def boolForKey:@"UseAppleIconApi"], [def stringForKey:@"FirstColumnStyle"]];
	self.procs = [PSProcArray psProcArrayWithIconSize:self.tableView.rowHeight];
	self.tableView.sectionHeaderHeight = self.tableView.sectionHeaderHeight * 3 / 2;
	self.colState = 0;
	// Default column order
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		@"Columns" : @[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
		@"SortColumn" : @1,
		@"SortDescending" : @NO,
		@"UpdateInterval" : @"1",
		@"FullWidthCommandLine" : @NO,
		@"AutoJumpNewProcess" : @NO,
		@"UseAppleIconApi" : @NO,
		@"CpuGraph" : @NO,
		@"FirstColumnStyle" : @"Bundle Identifier",
	}];
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
	// Status bar
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
		self.status.text = [NSString stringWithFormat:@"%.1f/%.1f MB  CPU: %.1f%%",
			(float)self.procs.memUsed / 1024 / 1024,
			(float)self.procs.memTotal / 1024 / 1024,
			(float)self.procs.totalCpu / 10];
	else
		self.status.text = [NSString stringWithFormat:@"\u2699 Processes: %u   Threads: %u   RAM: %.1f/%.1f MB   CPU: %.1f%%",
			self.procs.count,
			self.procs.threadCount,
			(float)self.procs.memUsed / 1024 / 1024,
			(float)self.procs.memTotal / 1024 / 1024,
			(float)self.procs.totalCpu / 10];
	// Uptime, CPU Freq, Cores, Cache L1/L2
	if (timer == nil) {
		// First time refresh: we don't need info about new processes
		[self.procs setAllDisplayed:ProcDisplayNormal];
	} else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoJumpNewProcess"]) {
		// If there's a new process, scroll to it
		NSUInteger idx = [self.procs indexOfDisplayed:ProcDisplayStarted];
		if (idx != NSNotFound)
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
				atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
		// [self.tableView insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
		// [self.tableView deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	}
}

- (void)refreshProcs
{
	[self refreshProcs:nil];
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
		[[NSUserDefaults standardUserDefaults] setInteger:col.tag-1 forKey:@"SortColumn"];
		[[NSUserDefaults standardUserDefaults] setBool:self.sortdesc forKey:@"SortDescending"];
		[self.timer fire];
		break;
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	// Check if some major options changed
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	NSString *majorCheck = [NSString stringWithFormat:@"%d-%@", [def boolForKey:@"UseAppleIconApi"], [def stringForKey:@"FirstColumnStyle"]];
	if (![self.majorOptions isEqualToString:majorCheck]) {
		self.majorOptions = majorCheck;
		self.procs = [PSProcArray psProcArrayWithIconSize:self.tableView.rowHeight];
	}
	self.firstColWidth = self.tableView.bounds.size.width;
	self.columns = [PSColumn psGetShownColumnsWithWidth:&_firstColWidth];
	// Column state has changed - recreate all table cells
// TODO: Optimize this!
	self.colState++;
	NSUInteger sortCol = [[NSUserDefaults standardUserDefaults] integerForKey:@"SortColumn"];
	if (sortCol >= self.columns.count) sortCol = self.columns.count - 1;
	self.sorter = self.columns[sortCol];
	self.sortdesc = [[NSUserDefaults standardUserDefaults] boolForKey:@"SortDescending"];
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(self.firstColWidth, self.tableView.sectionHeaderHeight)];
	[self.header sortColumnOld:nil New:self.sorter desc:self.sortdesc];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
	self.interval = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	[self refreshProcs];
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
	self.firstColWidth = self.tableView.bounds.size.width;
	self.columns = [PSColumn psGetShownColumnsWithWidth:&_firstColWidth];
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(self.firstColWidth, self.tableView.sectionHeaderHeight)];
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

// Section header will be used as a grid header
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	return self.header;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.procs.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row >= self.procs.count)
		return nil;
	PSProc *proc = self.procs[indexPath.row];
	NSString *CellIdentifier = [NSString stringWithFormat:@"%u-%u-%u", self.firstColWidth, self.colState, proc.icon ? 1 : 0];
	GridTableCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
		cell = [GridTableCell cellWithId:CellIdentifier columns:self.columns size:CGSizeMake(self.firstColWidth, tableView.rowHeight)];
//		[myObject configureCell:cell];
// TODO: configureCell vs. updateCell !!!!
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
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		PSProc *proc = self.procs[indexPath.row];
		// task_for_pid(mach_task_self(), pid, &task)
		// task_terminate(task)
		if (kill(proc.pid, SIGTERM)) {	// SIGTERM, SIGQUIT, SIGKILL
			NSString *msg = [NSString stringWithFormat:@"Error %d while terminating app", errno];
			UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:proc.name message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
			[alertView show];
		}
		// Refresh immediately to show process termination
		[self.timer performSelector:@selector(fire) withObject:nil afterDelay:.1f];
	}
}
/*
- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"Kill";
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:@"SIGKILL!" message:@"Killemall!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	[alertView show];
}

- (id)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewRowAction *moreRowAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"More" handler:
		(void (^)(UITableViewRowAction *action, NSIndexPath *indexPath))handler
{action, indexpath in println("MORE•ACTION");
	});
	moreRowAction.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0);
	var deleteRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete", handler:{action, indexpath in
		println("DELETE•ACTION");
	});
	return [deleteRowAction, moreRowAction];
}
*/

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (cell) {
		UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:cell.textLabel.text message:cell.detailTextLabel.text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
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
	self.status = nil;
	self.header = nil;
	self.sorter = nil;
	self.procs = nil;
	self.columns = nil;
	self.majorOptions = nil;
}

- (void)dealloc
{
	if (self.timer.isValid)
		[self.timer invalidate];
	[_timer release];
	[_status release];
	[_procs release];
	[_columns release];
	[_majorOptions release];
	[super dealloc];
}

@end
