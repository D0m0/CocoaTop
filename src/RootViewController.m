#import "RootViewController.h"
#import "SetupViewController.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"

@interface RootViewController()
{
}
@property (retain) NSArray *columns;
@property (retain) NSTimer *timer;
@property (retain) PSProcArray *procs;
@end

@implementation RootViewController

#pragma mark -
#pragma mark View lifecycle

- (void)openSettings
{
	SetupViewController* setupViewController = [[SetupViewController alloc] initWithColumns:self.columns];
	[self.navigationController pushViewController:setupViewController animated:YES];
	[setupViewController release];
}

- (void)refreshProcs
{
	[self.procs refresh];
	// [self.tableView insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	// [self.tableView deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	[self.tableView reloadData];
	// If there's a new process, scroll to it
//TODO: make it configurable!!!
	NSUInteger idx = [self.procs indexOfDisplayed:ProcDisplayStarted];
	if (idx != NSNotFound)
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
			atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
	//self.navigationItem.rightBarButtonItem = self.editButtonItem;
	//self.tableView.rowHeight = 30;
//	UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain
//		target:self action:@selector(refreshProcs)];
	UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStylePlain
		target:self action:@selector(openSettings)];
	self.navigationItem.rightBarButtonItem = anotherButton;
	[anotherButton release];
	self.procs = [PSProcArray psProcArrayWithIconSize:self.tableView.rowHeight];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	self.columns = [PSColumn psColumnsArray];
	[self.procs refresh];
	[self.procs setAllDisplayed:ProcDisplayNormal];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f 
		target:self selector:@selector(refreshProcs) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	if (self.timer.isValid)
		[self.timer invalidate];
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
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if ((fromInterfaceOrientation == UIInterfaceOrientationPortrait ||
		fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) &&
		(self.interfaceOrientation == UIInterfaceOrientationPortrait ||
		self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
		return;
	if ((fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
		fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight) &&
		(self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
		self.interfaceOrientation == UIInterfaceOrientationLandscapeRight))
		return;
	// Size changed - need to redraw
	[self.tableView setNeedsDisplay];
}
*/

#pragma mark -
#pragma mark Table view data source

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
//TODO: section 1: system processes, section 2: user processes
	return self.procs.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row >= self.procs.count)
		return nil;
	PSProc *proc = [self.procs procAtIndex:indexPath.row];
	NSString *CellIdentifier = [NSString stringWithFormat:@"%u", proc.pid];
	GridTableCell *cell = (GridTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
//TODO: Replace tableView.frame.size.width with maximum screen dimension?
	if (cell == nil)
		cell = [GridTableCell cellWithId:CellIdentifier proc:proc columns:self.columns size:CGSizeMake(tableView.frame.size.width, tableView.rowHeight)];
	else
		[cell updateWithProc:proc columns:self.columns];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	display_t display = [self.procs procAtIndex:indexPath.row].display;
	if (display == ProcDisplayTerminated)
		cell.backgroundColor = [UIColor colorWithRed:1 green:0.7 blue:0.7 alpha:1];
	else if (display == ProcDisplayStarted)
		cell.backgroundColor = [UIColor colorWithRed:0.7 green:1 blue:0.7 alpha:1];
	else if (indexPath.row & 1)
		cell.backgroundColor = [UIColor colorWithRed:.95 green:.95 blue:.95 alpha:1];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	// Return NO if you do not want the specified item to be editable.
	return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		// Delete the row from the data source.
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
	else if (editingStyle == UITableViewCellEditingStyleInsert)
	{
		// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
	}
}
*/

//TODO: Refresh on rotate!!!

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
	// Configure the cell.
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
