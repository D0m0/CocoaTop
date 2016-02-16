#import "Compat.h"
#import "SetupColumns.h"
#import "Column.h"
#import "TextViewController.h"

@interface SelectPreset : UITableViewController
@end

@implementation SelectPreset

- (instancetype)init
{
	return [super initWithStyle:UITableViewStyleGrouped];
}

//     0    1   2   3   4  5   6    7     8    9    10   11  12   13    14  15  16   17   18   19   20   21    22    23   24
// Command PID PPID % Time S Flags RMem VSize User Group TTY Thr Ports Mach BSD CSw Prio BPri Nice Role MSent MRecv RMax Phys
//   25    26    27     28    29    30    31   32   33  34   35    36    37    38    39     40      41     42    43    44     45     46     47
// DiskR DiskW SDiskR SDiskW STime SMach SBSD SCSw FDs Bid Bname BDname Bver OSver SDKver PlatVer Compil NetRx NetTx SNetRx SNetTx SPktRx SPktTx

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
				@"6: RAM usage":@[@0, @1, @7, @23, @24, @8],
				@"7: Net usage":@[@0, @1, @33, @42, @43, @44, @45],
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
				@"8: Disk usage":@[@0, @1, @25, @26, @27, @28],
#endif
			} retain];
		else
			presetList = [@{
				@"1: Standard":@[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
				@"2: Inspector":@[@0, @1, @3, @5, @6, @7, @9, @10, @12, @13],
				@"3: Performance":@[@0, @1, @3, @16, @4, @5, @17, @7, @23, @12, @13, @14, @15, @19],
				@"4: Minimalistic":@[@0, @1, @3, @5, @7, @20],
				@"5: Mach-obsessed":@[@0, @1, @5, @6, @7, @3, @12, @16, @13, @15, @14, @21, @22],
				@"6: RAM usage":@[@0, @1, @3, @5, @7, @23, @24, @8],
				@"7: Net usage":@[@0, @1, @3, @5, @33, @42, @43, @44, @45, @46, @47],
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
				@"8: Disk usage":@[@0, @1, @9, @25, @26, @27, @28, @24],
#endif
			} retain];
		presetNames = [[presetList.allKeys sortedArrayUsingSelector:@selector(compare:)] retain];
	});
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
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
	return @"Select a column layout";
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
		NSInteger i = [idx intValue];
		PSColumn *col = i ? [PSColumn psColumnWithTag:i] : nil;
		if (col) colNames = [colNames stringByAppendingFormat:@", %@", col.name];
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
@property(retain) NSMutableArray *in;
@property(retain) NSMutableArray *out;
@end

@implementation SetupColsViewController

- (void)openPresets
{
	SelectPreset* preset = [SelectPreset new];
	[self.navigationController pushViewController:preset animated:YES];
	[preset release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
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
	self.in = [PSColumn psGetShownColumnsWithWidth:100000000];
	self.out = [NSMutableArray array];
	for (PSColumn* col in [PSColumn psGetAllColumns])
		if (!(col.style & ColumnStyleForSummary))
			if (![self.in containsObject:col])
				[self.out addObject:col];
	ar[0] = self.in;
	ar[1] = self.out;
	[self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
	NSMutableArray *order = [NSMutableArray array];
	for (PSColumn* col in self.in)
		[order addObject:[NSNumber numberWithUnsignedInteger:col.tag]];
	[[NSUserDefaults standardUserDefaults] setObject:order forKey:@"Columns"];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

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

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)src
{
	[tableView selectRowAtIndexPath:src animated:YES scrollPosition:UITableViewScrollPositionNone];
	PSColumn *col = ar[src.section][src.row];
	[TextViewController showText:col.descr withTitle:col.fullname inViewController:self];
//	[tableView deselectRowAtIndexPath:src animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)src
{
	BOOL isUnmoveable = src.section == 0 && src.row == 0;
	BOOL hasDecription = ((PSColumn *)ar[src.section][src.row]).descr != nil;
	NSString *reuseId = [NSString stringWithFormat:@"SetupColumn-%d-%d", isUnmoveable, hasDecription];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseId];
	cell.textLabel.text = ((PSColumn *)ar[src.section][src.row]).fullname;
	cell.editingAccessoryType = hasDecription ? UITableViewCellAccessoryDetailButton : UITableViewCellAccessoryNone;
	return cell;
}

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
