#import "SetupColumns.h"
#import "Column.h"

@interface SetupColsViewController()
{
	NSMutableArray *ar[2];
}
@property (retain)NSMutableArray *in;
@property (retain)NSMutableArray *out;

@end

@implementation SetupColsViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.tableView.editing = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	NSUInteger width = 100000000;
	self.in = [PSColumn psGetShownColumnsWithWidth:&width];
	self.out = [NSMutableArray array];
	for (PSColumn* col in [PSColumn psGetAllColumns])
		if (![self.in containsObject:col])
			[self.out addObject:col];
	ar[0] = self.in;
	ar[1] = self.out;
	[self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
	NSArray *allCols = [PSColumn psGetAllColumns];
	NSMutableArray *order = [NSMutableArray array];
	for (PSColumn* col in self.in)
		[order addObject:[NSNumber numberWithUnsignedInteger:[allCols indexOfObject:col]]];
	[[NSUserDefaults standardUserDefaults] setObject:order forKey:@"Columns"];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return section == 0 ? @"Active" : @"Inactive";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return section == 1 ? @"These columns will not be shown" : nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return ar[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Reuse a single cell
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	cell.textLabel.text = ((PSColumn *)ar[indexPath.section][indexPath.row]).descr;
	return cell;
}

#pragma mark - Edit Mode
- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)src
{
	return src.section == 0 && src.row == 0 ? NO : YES;
//	return (src.section == 0 && src.row == 0) || (src.section > 1) ? NO : YES;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)src toProposedIndexPath:(NSIndexPath *)dst
{
	if (dst.section == 0 && dst.row == 0)
		return [NSIndexPath indexPathForRow:1 inSection:0];
//	if (dst.section > 1)
//		return [NSIndexPath indexPathForRow:[tableView numberOfRowsInSection:1]-1 inSection:1];
	return dst;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)src toIndexPath:(NSIndexPath *)dst
{
	id save = ar[src.section][src.row];
	[ar[src.section] removeObjectAtIndex:src.row];
	[ar[dst.section] insertObject:save atIndex:dst.row];
}

- (void)viewDidUnload
{
	self.in = nil;
	self.out = nil;
}

- (void)dealloc
{
	[_in release];
	[_out release];
	[super dealloc];
}

@end
