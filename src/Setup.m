#import "Setup.h"
#import "About.h"

@implementation SetupViewController

- (void)openAbout
{
	AboutViewController* about = [[AboutViewController alloc] initWithStyle:UITableViewStyleGrouped];
	[self.navigationController pushViewController:about animated:YES];
	[about release];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIBarButtonItem *aboutButton = [[UIBarButtonItem alloc] initWithTitle:@"The Story" style:UIBarButtonItemStylePlain
		target:self action:@selector(openAbout)];
	self.navigationItem.rightBarButtonItem = aboutButton;
	[aboutButton release];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.tableView.allowsSelection = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
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

struct optionsList_t {
	NSString*	accessory;
	UITableViewCellAccessoryType accType;
	NSString*	optionKey;
	NSString*	label;
};

struct optionsList_t optionsList[4] = {
	{@"UILabel", UITableViewCellAccessoryDisclosureIndicator, @"UpdateInterval", @"Update interval (seconds)"},
	{@"UISwitch", UITableViewCellAccessoryNone, @"FullWidthCommandLine", @"Full width command line"},
	{@"UISwitch", UITableViewCellAccessoryNone, @"AutoJumpNewProcess", @"Auto scroll to new/terminated processes"},
	{@"UISwitch", UITableViewCellAccessoryNone, @"UseAppleIconApi", @"Use Apple API to get App icons (needs restart)"},
//	{[UILabel class], UITableViewCellAccessoryDisclosureIndicator, @"FirstColumnStyle", @"First column style"},	// @"Bundle name" : @"Other"
//	{[UISwitch class], UITableViewCellAccessoryNone, @"CpuGraph", @"Show CPU Graph"},
};

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
	// Reuse a single cell
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Setup"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Setup"];
	struct optionsList_t *option = &optionsList[indexPath.row];
	cell.textLabel.text = option->label;
	if ([option->accessory isEqual:@"UISwitch"]) {
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
		if ([option->accessory isEqual:@"UILabel"]) {
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
			label.textAlignment = NSTextAlignmentRight;
			label.font = [UIFont systemFontOfSize:16.0];
			label.backgroundColor = [UIColor clearColor];
			label.text = [[NSUserDefaults standardUserDefaults] stringForKey:option->optionKey];
			// Bundle name / Executable name / With args / Full path with args
			label.tag = indexPath.row + 1;
			[cell.contentView addSubview:label];
			[label release];
		}
	}
	return cell;
	// Special process colors: Root / User / 32 bit / Zombie & Stuck
	// Manual Refresh button with arrows
	// Filter procs by string
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([optionsList[indexPath.row].accessory isEqual:@"UILabel"]) {
		UIView *label = [cell viewWithTag:indexPath.row + 1];
		CGSize size = cell.contentView.frame.size;
		label.frame = CGRectMake(size.width - 110, 0, 100, size.height);
	}
}

@end
