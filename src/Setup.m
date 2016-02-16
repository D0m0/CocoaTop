#import "Compat.h"
#import "Setup.h"

@interface SelectFromList : UITableViewController
@property (retain) NSArray *list;
@property (retain) NSString *option;
@property (retain) NSString *value;
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
	return [[[SelectFromList alloc] initWithList:list option:option] autorelease];
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

- (void)dealloc
{
	[_list release];
	[_option release];
	[_value release];
	[super dealloc];
}

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
	UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:@"Reset" message:@"Reset settings to default values?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil] autorelease];
	[alertView show];
}

struct optionsList_t {
	NSString*	accessory;
	UITableViewCellAccessoryType accType;
	NSString*	optionKey;
	NSString*	label;
	NSArray*	choose;
} optionsList[] = {
	{@"UILabel", UITableViewCellAccessoryDisclosureIndicator, @"UpdateInterval", @"Update interval (seconds)", nil},
	{@"UILabel", UITableViewCellAccessoryDisclosureIndicator, @"FirstColumnStyle", @"First column style", nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"FullWidthCommandLine", @"Full width command line", nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"ShortenPaths", @"Show short (symlinked) paths", nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"AutoJumpNewProcess", @"Auto scroll to new/terminated processes", nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"ShowHeader", @"Show column sort header", nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"ShowFooter", @"Show column totals (footer)", nil},
};

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIBarButtonItem *resetButton = [[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStylePlain
		target:self action:@selector(factoryReset)];
	self.navigationItem.rightBarButtonItem = resetButton;
	self.navigationItem.title = @"Settings";
	[resetButton release];

	if (!optionsList[0].choose)
		optionsList[0].choose = [@[@"0.5",@"1",@"2",@"3",@"5",@"10",@"Never"] retain];
	if (!optionsList[1].choose)
		optionsList[1].choose = [@[@"Bundle Identifier",@"Bundle Name",@"Bundle Display Name",@"Executable Name",@"Executable With Args"] retain];
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
	return sizeof(optionsList) / sizeof(struct optionsList_t);
}

- (void)flipSwitch:(id)sender
{
	UISwitch *onOff = (UISwitch *)sender;
	[[NSUserDefaults standardUserDefaults] setBool:onOff.on forKey:optionsList[onOff.tag - 1].optionKey];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *rid = indexPath.section ? @"SetupHelp" : @"Setup";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
	struct optionsList_t *option = &optionsList[indexPath.row];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.text = option->label;
	if ([option->accessory isEqualToString:@"UISwitch"]) {
		UISwitch *onOff = [[UISwitch alloc] initWithFrame:CGRectZero];
		[onOff addTarget:self action:@selector(flipSwitch:) forControlEvents:UIControlEventValueChanged];
		onOff.on = [[NSUserDefaults standardUserDefaults] boolForKey:option->optionKey];
//		onOff.onTintColor = [UIColor redColor];
		onOff.tag = indexPath.row + 1;
		cell.accessoryView = onOff;
		[onOff release];
	} else {
		cell.accessoryType = option->accType;
		cell.accessoryView = nil;
		if ([option->accessory isEqualToString:@"UILabel"]) {
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			cell.contentView.autoresizesSubviews = YES;
			UILabel *label = (UILabel *)[cell viewWithTag:indexPath.row + 1];
			if (!label) {
				label = [[UILabel alloc] initWithFrame:CGRectZero];
				label.textAlignment = NSTextAlignmentRight;
				label.font = [UIFont systemFontOfSize:16.0];
				label.textColor = [UIColor grayColor];
				label.backgroundColor = [UIColor clearColor];
				label.text = [[NSUserDefaults standardUserDefaults] stringForKey:option->optionKey];
				label.tag = indexPath.row + 1;
				label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
				[cell.contentView addSubview:label];
				[label release];
			} else
				label.text = [[NSUserDefaults standardUserDefaults] stringForKey:option->optionKey];
		}
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([optionsList[indexPath.row].accessory isEqualToString:@"UILabel"]) {
		UIView *label = [cell viewWithTag:indexPath.row + 1];
		[cell.textLabel sizeToFit];
		CGFloat labelstart = cell.textLabel.frame.size.width + 20;
		CGSize size = cell.contentView.frame.size;
		label.frame = CGRectMake(labelstart, 0, size.width - labelstart, size.height);
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([optionsList[indexPath.row].accessory isEqualToString:@"UILabel"]) {
		struct optionsList_t *option = &optionsList[indexPath.row];
		SelectFromList* selectView = [SelectFromList selectFromList:option->choose option:option->optionKey];
		[self.navigationController pushViewController:selectView animated:YES];
	}
}

@end
