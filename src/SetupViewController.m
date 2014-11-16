#import "SetupViewController.h"
#import "Column.h"

@interface SetupViewController()
{
	NSMutableArray *ar[2];
}
@property (retain)UITableView *tableView;
@property (retain)NSMutableArray *in;
@property (retain)NSMutableArray *out;

@end

@implementation SetupViewController

- (instancetype)initWithColumns:(NSArray *)columns
{
	if (self = [super init]) {
		self.in = [NSMutableArray array];
		for (PSColumn *col in columns)
			[self.in addObject:col.descr];
		self.out = [NSMutableArray array];
		ar[0] = self.in;
		ar[1] = self.out;
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
//	[self.view setBackgroundColor:[UIColor whiteColor]];
	self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 44)
		style:UITableViewStyleGrouped];
//	[self initTableItem];

	[self.view addSubview:self.tableView];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.tableView setEditing:YES];
	[self.tableView reloadData];
}
/*
- (void)initTableItem
{
	self.in = [NSMutableArray array];
	[self.in addObject:@"A"];
	[self.in addObject:@"Bo"];
	[self.in addObject:@"Br"];
	[self.in addObject:@"Ch"];
	[self.in addObject:@"Co"];
	[self.in addObject:@"E"];
	[self.in addObject:@"Pa"];
	[self.in addObject:@"Pe"];
	[self.in addObject:@"U"];
	[self.in addObject:@"V"];
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
	cell.textLabel.text = [ar[indexPath.section] objectAtIndex:indexPath.row];
	return cell;
}

#pragma mark - Edit Mode
- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
//	return indexPath.section == 0 && indexPath.row == 0 ? NO : YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)src toIndexPath:(NSIndexPath *)dst
{
	NSString *save = [ar[src.section] objectAtIndex:src.row];
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
