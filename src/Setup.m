#import "Compat.h"
#import "Setup.h"

@interface SelectFromList : UITableViewController
@property (strong) NSArray *list;
@property (strong) NSString *option;
@property (strong) NSString *value;
@end

@implementation SelectFromList

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (instancetype)initWithList:(NSArray *)list option:(NSString *)option
{
	self = [super initWithStyle:UITableViewStyleGrouped];
	self.list = list;
	self.option = option;
	self.value = [[NSUserDefaults standardUserDefaults] stringForKey:option];
	return self;
}

+ (instancetype)selectFromList:(NSArray *)list option:(NSString *)option
{
	return [[SelectFromList alloc] initWithList:list option:option];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationItem.title = @"Settings";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return @"Choose";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Setup"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Setup"];
	cell.textLabel.text = self.list[indexPath.row];
	cell.accessoryType = [self.value isEqualToString:cell.textLabel.text] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	self.value = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
	[[NSUserDefaults standardUserDefaults] setObject:self.value forKey:self.option];
	[self.navigationController popViewControllerAnimated:YES];
}

@end

@interface OptionItem : NSObject
+ (instancetype)withAccessory:(id)accessory key:(NSString *)optionKey label:(NSString *)label chooseFrom:(NSArray *)choose;
@property (assign) id accessory;
@property (strong) NSString *optionKey;
@property (strong) NSString *label;
@property (strong) NSArray *choose;
@end

@implementation OptionItem
+ (instancetype)withAccessory:(id)accessory key:(NSString *)optionKey label:(NSString *)label chooseFrom:(NSArray *)choose
{
	OptionItem *item = [OptionItem new];
	item.accessory = accessory;
	item.optionKey = optionKey;
	item.label = label;
	item.choose = choose;
	return item;
}
@end

@interface SetupViewController()
@property (strong) NSArray *optionsList;
@end

@implementation SetupViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 1) {
		[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
		[self.tableView reloadData];
	}
}

- (IBAction)factoryReset
{
	[[[UIAlertView alloc] initWithTitle:@"Reset" message:@"Reset settings to default values?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil] show];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.title = @"Settings";
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStylePlain
		target:self action:@selector(factoryReset)];
	self.optionsList = @[
		[OptionItem withAccessory:[UILabel class] key:@"UpdateInterval" label:@"Update interval (seconds)" chooseFrom:@[@"0.5",@"1",@"2",@"3",@"5",@"10",@"Never"]],
		[OptionItem withAccessory:[UILabel class] key:@"FirstColumnStyle" label:@"First column style" chooseFrom:@[@"Bundle Identifier",@"Bundle Name",@"Bundle Display Name",@"Executable Name",@"Executable With Args"]],
		[OptionItem withAccessory:[UISwitch class] key:@"FullWidthCommandLine" label:@"Full width command line" chooseFrom:nil],
		[OptionItem withAccessory:[UISwitch class] key:@"ShortenPaths" label:@"Show short (symlinked) paths" chooseFrom:nil],
		[OptionItem withAccessory:[UISwitch class] key:@"AutoJumpNewProcess" label:@"Auto scroll to new/terminated processes" chooseFrom:nil],
		[OptionItem withAccessory:[UISwitch class] key:@"ShowHeader" label:@"Show column sort header" chooseFrom:nil],
		[OptionItem withAccessory:[UISwitch class] key:@"ShowFooter" label:@"Show column totals (footer)" chooseFrom:nil],
	];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return @"General";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.optionsList.count;
}

- (void)flipSwitch:(id)sender
{
	UISwitch *onOff = (UISwitch *)sender;
	OptionItem *option = self.optionsList[onOff.tag - 1];
	[[NSUserDefaults standardUserDefaults] setBool:onOff.on forKey:option.optionKey];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *rid = indexPath.section ? @"SetupHelp" : @"Setup";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
	OptionItem *option = self.optionsList[indexPath.row];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.text = option.label;
	if (option.accessory == [UISwitch class]) {
		UISwitch *onOff = [[UISwitch alloc] initWithFrame:CGRectZero];
		[onOff addTarget:self action:@selector(flipSwitch:) forControlEvents:UIControlEventValueChanged];
		onOff.on = [[NSUserDefaults standardUserDefaults] boolForKey:option.optionKey];
//		onOff.onTintColor = [UIColor redColor];
		onOff.tag = indexPath.row + 1;
		cell.accessoryView = onOff;
	} else {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.accessoryView = nil;
		if (option.accessory == [UILabel class]) {
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			cell.contentView.autoresizesSubviews = YES;
			UILabel *label = (UILabel *)[cell viewWithTag:indexPath.row + 1];
			if (!label) {
				label = [[UILabel alloc] initWithFrame:CGRectZero];
				label.textAlignment = NSTextAlignmentRight;
				label.font = [UIFont systemFontOfSize:16.0];
				label.textColor = [UIColor grayColor];
				label.backgroundColor = [UIColor clearColor];
				label.text = [[NSUserDefaults standardUserDefaults] stringForKey:option.optionKey];
				label.tag = indexPath.row + 1;
				label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
				[cell.contentView addSubview:label];
			} else
				label.text = [[NSUserDefaults standardUserDefaults] stringForKey:option.optionKey];
		}
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	OptionItem *option = self.optionsList[indexPath.row];
	if (option.accessory == [UILabel class]) {
		UIView *label = [cell viewWithTag:indexPath.row + 1];
		[cell.textLabel sizeToFit];
		CGFloat labelstart = cell.textLabel.frame.size.width + 20;
		CGSize size = cell.contentView.frame.size;
		label.frame = CGRectMake(labelstart, 0, size.width - labelstart, size.height);
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	OptionItem *option = self.optionsList[indexPath.row];
	if (option.accessory == [UILabel class]) {
		SelectFromList* selectView = [SelectFromList selectFromList:option.choose option:option.optionKey];
		[self.navigationController pushViewController:selectView animated:YES];
	}
}

@end
