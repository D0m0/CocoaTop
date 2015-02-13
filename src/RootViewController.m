#import "RootViewController.h"
#import "Setup.h"
#import "SetupColumns.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"

@interface RootViewController()
{
	NSUInteger firstColWidth;
	NSInteger colState;
}
@property (retain) GridHeaderView *header;
@property (retain) NSArray *columns;
@property (retain) NSTimer *timer;
@property (retain) PSProcArray *procs;
@property (retain) PSColumn *sorter;
@property (retain) UILabel *status;
@property (assign) BOOL sortdesc;
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

	self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - 100, 40)];
	self.status.backgroundColor = [UIColor clearColor];
	UIBarButtonItem *cpuLoad = [[UIBarButtonItem alloc] initWithCustomView:self.status];
//	[self.status release];
	self.navigationItem.leftBarButtonItem = cpuLoad;	//leftBarButtonItems NSArray
	[cpuLoad release];

	self.procs = [PSProcArray psProcArrayWithIconSize:self.tableView.rowHeight];
	self.tableView.sectionHeaderHeight = self.tableView.sectionHeaderHeight * 3 / 2;
	colState = 0;
	// Default column order
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{@"Columns" : @[@0, @1, @2, @3, @6, @7, @8]}];
}

- (void)refreshProcs
{
	[self.procs refresh];
	if (self.sortdesc) {
		[self.procs sortWithComparator:^NSComparisonResult(PSProc *a, PSProc *b) { return self.sorter.sort(b, a); }];
	} else
		[self.procs sortWithComparator:self.sorter.sort];
	// [self.tableView insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	// [self.tableView deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	[self.tableView reloadData];
	self.status.text = [NSString stringWithFormat:@"\u2699 CPU Usage: 1%% | Physical Memory: 40%% | Processes: %u | Threads: 1000", self.procs.count];
	// Uptime, CPU Freq, Cores, Cache L1/L2

	// If there's a new process, scroll to it
	NSUInteger idx = [self.procs indexOfDisplayed:ProcDisplayStarted];
	if (idx != NSNotFound)
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
			atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)sortHeader:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint loc = [gestureRecognizer locationInView:self.header];
	for (PSColumn *col in self.columns) {
		NSUInteger width = col.tag == 1 ? firstColWidth : col.width;
		if (loc.x > width) {
			loc.x -= width;
			continue;
		}
		if (self.sorter != col) {
			UILabel *label = (UILabel *)[self.header viewWithTag:self.sorter.tag];
			label.textColor = [UIColor blackColor];
			label.text = self.sorter.name;
			self.sorter = col;
			self.sortdesc = NO;
		} else	// Sort descending
			self.sortdesc = !self.sortdesc;
		UILabel *label = (UILabel *)[self.header viewWithTag:col.tag];
		label.textColor = [UIColor whiteColor];
		label.text = [col.name stringByAppendingString:(self.sortdesc ? @"\u25BC" : @"\u25B2")];
		[self.timer fire];
		break;
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	firstColWidth = self.tableView.bounds.size.width;
	self.columns = [PSColumn psGetShownColumnsWithWidth:&firstColWidth];
	// Column state has changed - recreate all table cells
	colState++;
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(firstColWidth, self.tableView.sectionHeaderHeight)];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
// TODO: Initial sort column
	self.sorter = self.columns[1];
	[self.procs refresh];
	[self.procs sortWithComparator:self.sorter.sort];
	[self.procs setAllDisplayed:ProcDisplayNormal];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f 
		target:self selector:@selector(refreshProcs) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	if (self.timer.isValid)
		[self.timer invalidate];
	self.header = nil;
	self.columns = nil;
}

/*
- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations.
	return YES;//(interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if ((fromInterfaceOrientation == UIInterfaceOrientationPortrait || fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) &&
		(self.interfaceOrientation == UIInterfaceOrientationPortrait || self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
		return;
	if ((fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight) &&
		(self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft || self.interfaceOrientation == UIInterfaceOrientationLandscapeRight))
		return;
	// Size changed - need to redraw
	firstColWidth = self.tableView.bounds.size.width;
	self.columns = [PSColumn psGetShownColumnsWithWidth:&firstColWidth];
	// Column state has changed - recreate all table cells
//	colState++;
	self.header = [GridHeaderView headerWithColumns:self.columns size:CGSizeMake(firstColWidth, self.tableView.sectionHeaderHeight)];
	[self.header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
//	[self.tableView setNeedsDisplay];
	[self.timer fire];
}

#pragma mark -
#pragma mark Table view data source

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
//TODO: section 1: system processes, section 2: user processes
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
	NSString *CellIdentifier = [NSString stringWithFormat:@"%u-%u-%u", firstColWidth, colState, proc.icon ? 1 : 0];
	GridTableCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
		cell = [GridTableCell cellWithId:CellIdentifier columns:self.columns size:CGSizeMake(firstColWidth, tableView.rowHeight)];
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

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	/*
	<#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
	// ...
	// Pass the selected object to the new view controller.
	[self.navigationController pushViewController:detailViewController animated:YES];
	[detailViewController release];
	*/
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (cell) {
		UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:cell.textLabel.text message:cell.detailTextLabel.text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
	self.procs = nil;
	self.columns = nil;
}

- (void)dealloc
{
	if (self.timer.isValid)
		[self.timer invalidate];
	[_timer release];
	[_procs release];
	[_columns release];
	[super dealloc];
}

@end
