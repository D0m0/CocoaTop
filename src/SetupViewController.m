#import "SetupViewController.h"
#import "Column.h"

@interface SetupViewController()
{
	NSMutableArray *ar[2];
}
@property (retain)UITableView *tableView;
@property (retain)NSMutableArray *in;
@property (retain)NSMutableArray *out;
@property (retain)NSArray *cols;

@end

@implementation SetupViewController

- (instancetype)initWithColumns:(NSArray *)columns
{
	if (self = [super init]) {
		self.cols = columns;
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
//	[self.view setBackgroundColor:[UIColor whiteColor]];
	self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 44)
		style:UITableViewStyleGrouped];
	[self.view addSubview:self.tableView];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.tableView setEditing:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	// Default column order
	NSArray *conf = [defaults arrayForKey:@"Columns"];
		
	self.in = [NSMutableArray array];
	self.out = [NSMutableArray array];

	for (NSNumber* num in conf) {
		// NSDictionary: key=cid value=PSColumn ?????
		NSUInteger idx = [self.cols indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
			return ((PSColumn *)obj).cid == num;
		}];
		if (idx != NSNotFound)
			[self.in addObject:self.cols[idx]];
	}
	for (PSColumn* col in self.cols)
		if (![self.in containsObject:col])
			[self.out addObject:col];

	ar[0] = self.in;
	ar[1] = self.out;
//	[self initTableItem];

	[self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *cols = [NSMutableArray array];
	for (PSColumn* col in self.in)
		[cols addObject:col.cid];
	[defaults setObject:cols forKey:@"Columns"];
//	[defaults setObject:@[@0, @1, @2, @3, @4, @5] forKey:@"Columns"];
}

/*
- (void)initTableItem
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	// Default column order
	NSArray *conf = [defaults arrayForKey:@"Columns"]];

	self.in = [NSMutableArray array];
	for (NSNumber* num in conf)
		[self.in addObject:[NSString stringWithFormat:@"col %@", num]];
//	[self.in addObject:@"Bo"];
//	[self.in addObject:@"Br"];
//	[self.in addObject:@"Ch"];
//	[self.in addObject:@"Co"];
//	[self.in addObject:@"E"];
//	[self.in addObject:@"Pa"];
//	[self.in addObject:@"Pe"];
//	[self.in addObject:@"U"];
//	[self.in addObject:@"V"];
	self.out = [NSMutableArray array];
	ar[0] = self.in;
	ar[1] = self.out;
}
*/
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
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	}
	cell.textLabel.text = ((PSColumn *)[ar[indexPath.section] objectAtIndex:indexPath.row]).descr;
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
	id save = [ar[src.section] objectAtIndex:src.row];
	[ar[src.section] removeObjectAtIndex:src.row];
	[ar[dst.section] insertObject:save atIndex:dst.row];
}

- (void)viewDidUnload
{
	self.in = nil;
	self.out = nil;
	self.tableView = nil;
}

- (void)dealloc
{
	[_in release];
	[_out release];
	[_tableView release];
	[super dealloc];
}

@end
