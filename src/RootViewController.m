#import "RootViewController.h"
#import "GridCell.h"
#import "Proc.h"

@interface RootViewController()
{
	NSMutableArray *procs;
}
@end

@implementation RootViewController

#pragma mark -
#pragma mark View lifecycle


- (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki
{
	NSMutableArray*	args = nil;
	int			nargs, c = 0;
	static int	argmax = 0;
	char		*argsbuf, *sp, *cp;
	int			mib[3] = {CTL_KERN, KERN_PROCARGS2, ki->kp_proc.p_pid};
	size_t		size;

	if (!argmax) {
		int mib2[2] = {CTL_KERN, KERN_ARGMAX};
		size = sizeof(argmax);
		if (sysctl(mib2, 2, &argmax, &size, NULL, 0) < 0)
			argmax = 1024;
	}
	// Allocate process environment buffer
	argsbuf = (char *)malloc(argmax);
	if (argsbuf) {
		size = (size_t)argmax;
		if (sysctl(mib, 3, argsbuf, &size, NULL, 0) == 0) {
			// Skip args count
			nargs = *(int *)argsbuf;
			cp = argsbuf + sizeof(nargs);
			// Skip exec_path and trailing nulls
			for (; cp < &argsbuf[size]; cp++)
				if (!*cp) break;
			for (; cp < &argsbuf[size]; cp++)
				if (*cp) break;
			// Now find the size of all args
			for (sp = cp; cp < &argsbuf[size] && c < nargs; cp++)
				if (*cp == '\0') c++;
			if (sp != cp) {
				args = [[[[NSString alloc] initWithBytes:sp length:(cp-sp)
					encoding:NSUTF8StringEncoding]		// NSASCIIStringEncoding?
					autorelease] componentsSeparatedByString:@"\0"];
				[args filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(NSString *obj, NSDictionary *bind) {
					return obj.length != 0;
				}]];
			}
		}
		free(argsbuf);
	}
	return args != nil ? args : [NSArray arrayWithObject:[NSString stringWithFormat:@"(%s)", ki->kp_proc.p_comm]];
}

- (int)populate
{
	struct kinfo_proc *kp;
	int nentries;
	size_t bufSize;
	int i, err;
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};

	if (sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0)
		return errno;
	kp = (struct kinfo_proc *)malloc(bufSize);
	err = sysctl(mib, 4, kp, &bufSize, NULL, 0);
	if (!err) {
		nentries = bufSize / sizeof(struct kinfo_proc);
		for (i = 0; i < nentries; i++) {
			kp[i].kp_proc.p_comm[MAXCOMLEN] = 0;	// Just in case
			[procs addObject:[PSProc psprocWithKinfo:&kp[i] args:[self getArgsByKinfo:&kp[i]]]];
		}
	}
	free(kp);
	return err;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
	//self.navigationItem.rightBarButtonItem = self.editButtonItem;
	//self.tableView.rowHeight = 30;
	//self.tableView.separatorColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:1];

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
		
		cell.textLabel.text = [NSString stringWithFormat:@"Process #%u/%u: %@", proc.pid, proc.ppid, proc.name];

		NSString *full = [NSString stringWithString:[proc.args objectAtIndex:0]];
		for (int i = 1; i < proc.args.count; i++)
			full = [full stringByAppendingFormat:@" %@", [proc.args objectAtIndex:i]];
		cell.detailTextLabel.text = full;

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
