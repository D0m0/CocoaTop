#import "SetupColumns.h"
#import "Column.h"

@interface SelectPreset : UITableViewController
@end

@implementation SelectPreset

- (instancetype)init
{
	return [super initWithStyle:UITableViewStyleGrouped];
}

//     0    1   2   3  4   5   6    7     8    9    10   11  12   13    14  15  16   17   18   19   20   21    22    23    24   25  26
// Command PID PPID % Time S Flags RMem VSize User Group TTY Thr Ports Mach BSD CSw Prio BPri Nice Role MSent MRecv SMach SBSD SCSw FDs
//  27   28   29    30     31     32    33    34  35     36    37   38     39     40      41     42    43    44     45     46     47
// RMax Phys DiskR DiskW SDiskR SDiskW STime Bid Bname BDname Bver OSver SDKver PlatVer Compil NetRx NetTx SNetRx SNetTx SPktRx SPktTx

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
				@"6: RAM usage":@[@0, @1, @7, @27, @28, @8],
				@"7: Disk usage":@[@0, @1, @29, @30, @31, @32],
				@"8: Net usage":@[@0, @1, @26, @42, @43, @44, @45],
			} retain];
		else
			presetList = [@{
				@"1: Standard":@[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
				@"2: Inspector":@[@0, @1, @3, @5, @6, @7, @9, @10, @12, @13],
				@"3: Performance":@[@0, @1, @3, @16, @4, @5, @17, @7, @27, @12, @13, @14, @15, @19],
				@"4: Minimalistic":@[@0, @1, @3, @5, @7, @20],
				@"5: Mach-obsessed":@[@0, @1, @5, @6, @7, @3, @12, @16, @13, @15, @14, @21, @22],
				@"6: RAM usage":@[@0, @1, @3, @5, @7, @27, @28, @8],
				@"7: Disk usage":@[@0, @1, @9, @29, @30, @31, @32, @28],
				@"8: Net usage":@[@0, @1, @3, @5, @26, @42, @43, @44, @45, @46, @47],
			} retain];
		presetNames = [[presetList.allKeys sortedArrayUsingSelector:@selector(compare:)] retain];
	});
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
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
@property(retain) NSMutableArray *in;
@property(retain) NSMutableArray *out;
@property(retain) UIView *dimmer;
@end

@implementation SetupColsViewController

- (void)openPresets
{
	SelectPreset* preset = [SelectPreset new];
	[self.navigationController pushViewController:preset animated:YES];
	[preset release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
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

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	if (self.dimmer) [self.dimmer removeFromSuperview];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)src
{
	NSLog(@"accessoryButtonTappedForRowWithIndexPath %@", src);
	NSString *title = ((PSColumn *)ar[src.section][src.row]).fullname;
	NSString *message = ((PSColumn *)ar[src.section][src.row]).descr;

	// In iOS 9 UIPopoverController is deprecated, the effect of this being that background isn't dimmed
	if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_9_0) {
		if (self.dimmer == nil) {
			self.dimmer = [[UIView alloc] initWithFrame:self.navigationController.view.bounds];
			self.dimmer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
		}
		[self.navigationController.view addSubview:self.dimmer];
	}

	UIView *modal_view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 480, 480)];
	titleLabel.font = [UIFont systemFontOfSize:16.0];
	titleLabel.backgroundColor = [UIColor clearColor];
	titleLabel.textColor = [UIColor blackColor];
	titleLabel.text = message;
	titleLabel.textAlignment = NSTextAlignmentLeft;
	titleLabel.numberOfLines = 0;
	titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
//	titleLabel.preferredMaxLayoutWidth
	[titleLabel sizeToFit];
	[modal_view addSubview:titleLabel];

	UIViewController *contentController = [UIViewController new];
	contentController.view = modal_view;
	contentController.preferredContentSize = CGSizeMake(500, 500);
//	contentController.contentSizeForViewInPopover = CGSizeMake(350, 350);

	UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:contentController];
	popover.delegate = self;

	CGRect rectForWindow = CGRectMake(self.navigationController.view.bounds.size.width/2, self.navigationController.view.bounds.size.height/2, 1, 1);
	UIPopoverArrowDirection arrows = 0;	// UIPopoverArrowDirectionDown | UIPopoverArrowDirectionUp
//	CGSize contentSize = (CGSize){320, 460};
//	[popover setPopoverContentSize:contentSize];
	[popover presentPopoverFromRect:rectForWindow /*((UIButton *)button).bounds*/ inView: /*((UIButton *)button*/ self.navigationController.view permittedArrowDirections:arrows animated:YES];

//	NSString *title = @"Title";
//	NSString *message = @"Message";	// 0x2022
/*
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	alert.alertViewStyle = UIAlertViewStyleSecureTextInput;
	UITextField *myTextField = [alert textFieldAtIndex:0];
	[alert setTag:555];
	myTextField.keyboardType = UIKeyboardTypeAlphabet;
	[alert show];
*/
/*
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:title message:@"" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
//	UIImageView *view = [[UIImageView alloc] initWithFrame:CGRectMake(180, 10, 85, 50)];
//	UIImage *wonImage = [UIImage imageNamed:@"Icon.png"];
//	[view setImage:wonImage];
	UILabel *view;
	view = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 350, 200)];//[UILabel new];
	view.font = [UIFont systemFontOfSize:16.0];
//	view.backgroundColor = [UIColor clearColor];
	view.numberOfLines = 0;
	view.lineBreakMode = NSLineBreakByWordWrapping;
	view.textAlignment = NSTextAlignmentLeft;
	view.text = message;
//	view.preferredMaxLayoutWidth

	if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
		[alert setValue:view forKey:@"accessoryView"];
	} else {
		[alert addSubview:view];
	}
	[alert show];
*/
//	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
//	[alert show];
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
	self.dimmer = nil;
}

- (void)dealloc
{
	[_in release];
	[_out release];
	[_dimmer release];
	[super dealloc];
}

@end
