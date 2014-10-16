#import "RootViewController.h"
#import "GridCell.h"
#import "Proc.h"

@implementation RootViewController

#pragma mark -
#pragma mark View lifecycle

NSMutableArray *procs;

- (int)populate
{
	struct kinfo_proc *kp, *kprocbuf;
	int nentries, retry_count;
	size_t orig_bufSize, bufSize;
	int i, err;
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};

	if (sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0) {
		//perror("Failure calling sysctl");
		return 0;
	}
	kprocbuf = kp = (struct kinfo_proc *)malloc(bufSize);
	orig_bufSize = bufSize;
	for (retry_count = 0; ; retry_count++) {
		/* retry for transient errors due to load in the system */
		bufSize = orig_bufSize;
		err = sysctl(mib, 4, kp, &bufSize, NULL, 0);
		if (err < 0 && retry_count >= 1000) {
			//perror("Failure calling sysctl");
			return 0;
		} else if (err == 0)
			break;
		sleep(1);
	}
	nentries = bufSize / sizeof(struct kinfo_proc);
	for (i = 0; i < nentries; i++) {
		kp[i].kp_proc.p_comm[MAXCOMLEN] = 0;
		[procs addObject:[[PSProc alloc] initWithKInfoProc:&kp[i]]];
	}
	free(kprocbuf);
	return 0;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
	//self.navigationItem.rightBarButtonItem = self.editButtonItem;
	//self.tableView.rowHeight = 30;
	self.tableView.separatorColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:1];

	// array of struct kinfo_proc
	procs = [[NSMutableArray alloc] init];
	[self populate];
	[procs sortUsingComparator:^NSComparisonResult(PSProc *a, PSProc *b) {
		return a.pid - b.pid;
	}];
}

/*
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}
*/

/*
 // Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations.
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
 */

#pragma mark -
#pragma mark Table view data source

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;  // 2 - system + user!
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return procs.count;		// section 1: system processes, section 2: user processes
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSProc *proc;
	if (indexPath.row >= procs.count)
		return nil;
	proc = [procs objectAtIndex:(indexPath.row)];
	
	NSString *CellIdentifier = [NSString stringWithFormat:@"%u", proc.pid];

	GridTableCell *cell = (GridTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[GridTableCell alloc] initWithHeight:tableView.rowHeight Id:CellIdentifier] autorelease];
		
		cell.textLabel.text = [NSString stringWithFormat:@"Process #%u/%u", proc.pid, proc.ppid];
		cell.detailTextLabel.text = proc.name;

		cell.accessoryType = indexPath.row < 5 ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryNone;
		cell.indentationLevel = proc.ppid <= 1 ? 0 : 1;
		
		/*
		UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(shift, skew, col - shift, skew)] autorelease];
		label.tag = 1;
		label.font = [UIFont systemFontOfSize:12.0];
		label.text = [NSString stringWithFormat:@"Process #%u command line parameters", indexPath.row];
		label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
		[cell.contentView addSubview:label];
		*/
	}
	return cell;
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

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
	//
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	// Return NO if you do not want the item to be re-orderable.
	return YES;
}
*/

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
	if (cell != nil)
	{
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
	
	// Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	procs = nil;
}

- (void)dealloc
{
	[procs release];
	[super dealloc];
}

@end
