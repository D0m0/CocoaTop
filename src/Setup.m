#import "Setup.h"
#import "About.h"

@interface SelectFromList : UITableViewController
@property (retain) NSArray *list;
@property (retain) NSString *option;
@property (retain) NSString *value;
@property (retain) NSString *footer;
@end

@implementation SelectFromList

- (instancetype)initWithList:(NSArray *)list option:(NSString *)option footer:(NSString *)footer
{
	self = [super initWithStyle:UITableViewStyleGrouped];
	self.list = list;
	self.option = option;
	self.footer = footer;
	self.value = [[NSUserDefaults standardUserDefaults] stringForKey:option];
	return self;
}

+ (instancetype)selectFromList:(NSArray *)list option:(NSString *)option footer:(NSString *)footer
{
	return [[[SelectFromList alloc] initWithList:list option:option  footer:footer] autorelease];
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

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return self.footer;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"About"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"About"];
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


@implementation SetupViewController

- (void)openAbout
{
	AboutViewController* about = [[AboutViewController alloc] initWithStyle:UITableViewStyleGrouped];
	[self.navigationController pushViewController:about animated:YES];
	[about release];
}

struct optionsList_t {
	NSString*	accessory;
	UITableViewCellAccessoryType accType;
	NSString*	optionKey;
	NSString*	label;
	NSArray*	choose;
	NSString*	footer;
} optionsList[] = {
	{@"UILabel", UITableViewCellAccessoryDisclosureIndicator, @"UpdateInterval", @"Update interval (seconds)", nil, @"Note: tap the status header to refresh manually"},
	{@"UILabel", UITableViewCellAccessoryDisclosureIndicator, @"FirstColumnStyle", @"First column style", nil, nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"FullWidthCommandLine", @"Full width command line", nil, nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"ShortenExecutablePaths", @"Shorten executable paths", nil, nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"AutoJumpNewProcess", @"Auto scroll to new/terminated processes", nil, nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"ShowHeader", @"Show column header", nil, nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"ShowFooter", @"Show totals (footer)", nil, nil},
	{@"UISwitch", UITableViewCellAccessoryNone, @"UseAppleIconApi", @"Use Apple API to get App icons", nil, nil},
//	{@"UISwitch", UITableViewCellAccessoryNone, @"CpuGraph", @"Show CPU Graph", nil, nil},
};

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIBarButtonItem *aboutButton = [[UIBarButtonItem alloc] initWithTitle:@"The Story" style:UIBarButtonItemStylePlain
		target:self action:@selector(openAbout)];
	self.navigationItem.rightBarButtonItem = aboutButton;
	self.navigationItem.title = @"Settings";
	[aboutButton release];

	if (!optionsList[0].choose)
		optionsList[0].choose = [@[@"0.5",@"1",@"2",@"3",@"5",@"10",@"Never"] retain];
	if (!optionsList[1].choose)
		optionsList[1].choose = [@[@"Bundle Identifier",@"Bundle Name",@"Bundle Display Name",@"Executable Name",@"Executable With Args"] retain];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return section ? @"Quick guide" : @"General";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return section == 0 ? @"More options will be available in future versions" : nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return section ? 1 : sizeof(optionsList) / sizeof(struct optionsList_t);
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static const int numberOfLines = 46;
	return indexPath.section ? 44.0 + (numberOfLines - 1) * 19.0 : tableView.rowHeight;
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
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	if (indexPath.section == 0) {
		struct optionsList_t *option = &optionsList[indexPath.row];
		cell.textLabel.text = option->label;
		if ([option->accessory isEqualToString:@"UISwitch"]) {
			UISwitch *onOff = [[UISwitch alloc] initWithFrame:CGRectZero];
			[onOff addTarget:self action:@selector(flipSwitch:) forControlEvents:UIControlEventValueChanged];
			onOff.on = [[NSUserDefaults standardUserDefaults] boolForKey:option->optionKey];
//			onOff.onTintColor = [UIColor redColor];
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
	} else {
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.textLabel.font = [UIFont systemFontOfSize:16.0];
		cell.textLabel.text =
			@"Process states (similar to original top):\n"
			"	R	Running (at least one thread within this process is running right now)\n"
			"	U	Uninterruptible/'Stuck' (a thread is waiting on I/O in a system call)\n"
			"	S	Sleeping (all threads of a process are sleeping)\n"
			"	I	Idle (all threads are sleeping for at least 20 seconds)\n"
			"	T	Terminated (all threads stopped)\n"
			"	H	Halted (all threads halted at a clean point)\n"
			"	D	The process is stopped by a signal (can be used for debugging)\n"
			"	Z	Zombie (awaiting termination or 'orphan')\n"
			"	?	Running state is unknown (access to threads was denied)\n"
			"	\u25BC	Nice (lower priority, also see 'Nice' column)\n"
			"	\u25B2	Not nice (higher priority)\n"
			"	t	Process being traced, see P_TRACED below\n"
			"	z	Process being terminated at the moment, see P_WEXIT below\n"
			"	w	Process' parent is waiting for action after fork, see P_PPWAIT below\n"
			"	K	The system process (kernel), see P_SYSTEM below\n"
			"	B	Application is suspended by SpringBoard (iOS specific)\n"
			"\nProcess flags (will surely be deciphered in future versions):\n"
			"	0001	P_ADVLOCK		Process may hold POSIX adv. lock\n"
			"	0002	P_CONTROLT		Has a controlling terminal\n"
			"	0004	P_LP64 			64-bit process\n"
			"	0008	P_NOCLDSTOP	Bad parent: no SIGCHLD when children stop\n"
			"	0010	P_PPWAIT		\tParent is waiting for this child to exec/exit\n"
			"	0020	P_PROFIL		\tHas started profiling\n"
			"	0040	P_SELECT		\tSelecting; wakeup/waiting danger\n"
			"	0080	P_CONTINUED 	Process was stopped and continued\n"
			"	0100	P_SUGID			Has set privileges since last exec\n"
			"	0200	P_SYSTEM		\tSystem process: no signals, stats or swap\n"
			"	0400	P_TIMEOUT		Timing out during sleep\n"
			"	0800	P_TRACED		\tDebugged process being traced\n"
			"	1000	P_DISABLE_ASLR	Disable address space layout randomization\n"
			"	2000	P_WEXIT			Process is working on exiting\n"
			"	4000	P_EXEC			Process has called exec\n"
			"\nTask role (Mac specific):\n"
			"	None		\tNon-UI task\n"
			"	Foreground	\tNormal UI application in the foreground\n"
			"	Inactive 	\tNormal UI application in the background\n"
			"	Background	OS X: Normal UI application in the background\n"
			"	Controller	\tOS X: Controller service application\n"
			"	GfxServer	\tOS X: Graphics management (window) server\n"
			"	Throttle	\t\tOS X: Throttle application"
		;
	}
	return cell;
	// Special process colors: Root / User / 32 bit / Zombie & Stuck
	// Manual Refresh button with arrows
	// Filter procs by string
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0 && [optionsList[indexPath.row].accessory isEqualToString:@"UILabel"]) {
		UIView *label = [cell viewWithTag:indexPath.row + 1];
		[cell.textLabel sizeToFit];
		CGFloat labelstart = cell.textLabel.frame.size.width + 20;
		CGSize size = cell.contentView.frame.size;
		label.frame = CGRectMake(labelstart, 0, size.width - labelstart, size.height);
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0 && [optionsList[indexPath.row].accessory isEqualToString:@"UILabel"]) {
		struct optionsList_t *option = &optionsList[indexPath.row];
		SelectFromList* selectView = [SelectFromList selectFromList:option->choose option:option->optionKey footer:option->footer];
		[self.navigationController pushViewController:selectView animated:YES];
	}
}

@end
