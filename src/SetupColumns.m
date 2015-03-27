#import "SetupColumns.h"
#import "Column.h"

@interface SelectPreset : UITableViewController
@end

@implementation SelectPreset

- (instancetype)init
{
	return [super initWithStyle:UITableViewStyleGrouped];
}

//     0    1   2   3  4   5   6    7     8    9    10   11  12   13    14  15  16   17   18   19   20   21    22
// Command PID PPID % Time S Flags RMem VSize User Group TTY Thr Ports Mach BSD CSw Prio BPri Nice Role MSent MRecv
static NSDictionary *presetList;
static NSArray *presetNames;

- (void)viewDidLoad
{
	[super viewDidLoad];
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
			presetList = [@{
				@"1: Standard":@[@0, @1, @3, @5, @20, @6, @7],
				@"2: Inspector":@[@0, @3, @5, @6, @7, @9, @12],
				@"3: Performance":@[@0, @3, @16, @4, @5, @17, @7, @12],
				@"4: Minimalistic":@[@0, @3, @7],
				@"5: Mach-obsessed":@[@0, @3, @12, @13, @15, @14, @21, @22],
			} retain];
		else
			presetList = [@{
				@"1: Standard":@[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
				@"2: Inspector":@[@0, @1, @3, @5, @6, @7, @9, @10, @12, @13],
				@"3: Performance":@[@0, @1, @3, @16, @4, @5, @17, @7, @12, @13, @14, @15, @19],
				@"4: Minimalistic":@[@0, @1, @3, @5, @7, @20],
				@"5: Mach-obsessed":@[@0, @1, @5, @6, @7, @3, @12, @16, @13, @15, @14, @21, @22],
			} retain];
		presetNames = [[presetList.allKeys sortedArrayUsingSelector:@selector(compare:)] retain];
	});
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationItem.title = @"Column presets";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return @"Select a preset column layout";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return presetList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Preset"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Preset"];
	cell.textLabel.text = presetNames[indexPath.row];
	NSString *colNames = @"Command";
	for (NSNumber *idx in presetList[presetNames[indexPath.row]]) {
		int i = [idx intValue];
		if (i) colNames = [colNames stringByAppendingFormat:@", %@", ((PSColumn *)[PSColumn psGetAllColumns][i]).name];
	}
	cell.detailTextLabel.text = colNames;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[[NSUserDefaults standardUserDefaults] setObject:presetList[presetNames[indexPath.row]] forKey:@"Columns"];
	[self.navigationController popViewControllerAnimated:YES];
}

@end


@interface SetupColsViewController()
{
	NSMutableArray *ar[2];
}
@property (retain)NSMutableArray *in;
@property (retain)NSMutableArray *out;
@end

@implementation SetupColsViewController

- (void)openPresets
{
	SelectPreset* preset = [SelectPreset new];
	[self.navigationController pushViewController:preset animated:YES];
	[preset release];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.tableView.editing = YES;
	UIBarButtonItem *presetButton = [[UIBarButtonItem alloc] initWithTitle:@"Presets" style:UIBarButtonItemStylePlain
		target:self action:@selector(openPresets)];
	self.navigationItem.rightBarButtonItem = presetButton;
	self.navigationItem.title = @"Manage columns";
	[presetButton release];
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
	return section == 0 ? @"Shown columns" : @"Inactive columns";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return section == 0 ? @"Only columns that fit will actually be shown" : nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return ar[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)src
{
	// Stupid non-draggable cell should be created separately
	NSString *reuse = (src.section == 0 && src.row == 0) ? @"SetupUnmovableColumn" : @"SetupColumns";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
	cell.textLabel.text = ((PSColumn *)ar[src.section][src.row]).descr;
	return cell;
}

#pragma mark - Edit Mode
- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)src
{
	return !(src.section == 0 && src.row == 0);
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)src toProposedIndexPath:(NSIndexPath *)dst
{
	if (dst.section == 0 && dst.row == 0)
		return [NSIndexPath indexPathForRow:1 inSection:0];
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
