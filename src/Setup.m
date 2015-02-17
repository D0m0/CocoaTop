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
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return section ? @"Quick guide" : @"General";
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
	return section ? 1 : sizeof(optionsList) / sizeof(struct optionsList_t);
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static const int numberOfLines = 37;
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
	if (indexPath.section) {
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.textLabel.font = [UIFont systemFontOfSize:16.0];
		cell.textLabel.text =
			@"Process states (similar to original top):\n"
			"	R	Running (at least one thread within this process is running right now)\n"
			"	U	Uninterruptible/'Stuck' (a thread is waiting on I/O in a system call)\n"
			"	S	Sleeping (all threads are sleeping)\n"
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
			"	B	The application is suspended by SpringBoard (iOS specific)\n"
			"\nProcess flags (will surely be deciphered in future versions):\n"
			"	0001	P_ADVLOCK		Process may hold POSIX adv. lock\n"
			"	0002	P_CONTROLT		Has a controlling terminal\n"
			"	0004	P_LP64			\t64-bit process\n"
			"	0008	P_NOCLDSTOP	Bad parent: no SIGCHLD when children stop\n"
			"	0010	P_PPWAIT		\tParent is waiting for this child to exec/exit\n"
			"	0020	P_PROFIL		\tHas started profiling\n"
			"	0040	P_SELECT		\tSelecting; wakeup/waiting danger\n"
			"	0080	P_CONTINUED		Process was stopped and continued\n"
			"	0100	P_SUGID			Has set privileges since last exec\n"
			"	0200	P_SYSTEM		\tSystem process: no signals, stats or swap\n"
			"	0400	P_TIMEOUT		Timing out during sleep\n"
			"	0800	P_TRACED		\tDebugged process being traced\n"
			"	1000	P_DISABLE_ASLR	Disable address space layout randomization\n"
			"	2000	P_WEXIT			Process is working on exiting\n"
			"	4000	P_EXEC			Process has called exec\n"
		;
	} else {
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
