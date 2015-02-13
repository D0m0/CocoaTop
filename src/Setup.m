#import "Setup.h"
#import "Column.h"

@implementation SetupViewController

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
	return @"Main";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 7;
}

- (void)flipSwitch:(id)sender
{
	UISwitch *onOff = (UISwitch *)sender;
	switch (onOff.tag) {
	case 2: [[NSUserDefaults standardUserDefaults] setBool:onOff.on forKey:@"FullWidthCommandLine"]; break;
	case 3: [[NSUserDefaults standardUserDefaults] setBool:onOff.on forKey:@"AutoJumpNewProcess"]; break;
	case 4: [[NSUserDefaults standardUserDefaults] setBool:onOff.on forKey:@"UseAppleIconApi"]; break;
	case 6: [[NSUserDefaults standardUserDefaults] setBool:onOff.on forKey:@"CpuGraph"]; break;
	}
//	UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:[NSString stringWithFormat:@"Tag = %d", onOff.tag] message:(onOff.on ? @"YES" : @"NO") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//	[alertView show];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Reuse a single cell
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	UISwitch *onOff;
	UILabel *label;
	switch (indexPath.row) {
	case 0:
	case 2:
	case 3:
	case 4:
	case 6:
		onOff = [[UISwitch alloc] initWithFrame:CGRectZero];
		[onOff addTarget:self action:@selector(flipSwitch:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = onOff;
		onOff.tag = indexPath.row;
		[onOff release];
		break;
	case 1:
	case 5:
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.textAlignment = NSTextAlignmentRight;
		label.font = [UIFont systemFontOfSize:16.0];
		label.backgroundColor = [UIColor clearColor];
		// Bundle name / Executable name / With args / Full path with args
		label.tag = 1;//indexPath.row;
		[cell.contentView addSubview:label];
		[label release];
		cell.accessoryView = nil;
		break;
	}
	switch (indexPath.row) {
	case 0:
		onOff.onTintColor = [UIColor redColor];
		cell.textLabel.text = @"Main Power Switch"; break;
	case 1:
		label.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"UpdateInterval"];
		cell.textLabel.text = @"Update interval (seconds)"; break;
	case 2:
		onOff.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"FullWidthCommandLine"];
		cell.textLabel.text = @"Full width command line"; break;
	case 3:
		onOff.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"AutoJumpNewProcess"];
		cell.textLabel.text = @"Auto jump to new/terminated processes"; break;
	case 4:
		onOff.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseAppleIconApi"];
		cell.textLabel.text = @"Use Apple API to get App icons (needs restart)"; break;
	case 5:
		label.text = [[NSUserDefaults standardUserDefaults] integerForKey:@"FirstColumnStyle"] == 1 ? @"Bundle name" : @"Other";
		cell.textLabel.text = @"First column style"; break;
	case 6:
		onOff.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"CpuGraph"];
		cell.textLabel.text = @"Show CPU Graph"; break;
	}
	return cell;
	// Special process colors: Root / User / 32 bit / Zombie & Stuck
	// Manual Refresh button with arrows
	// Filter procs by string
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	UIView *label = [cell viewWithTag:1];
	if (label) {
		CGSize size = cell.contentView.frame.size;
		label.frame = CGRectMake(size.width - 110, 0, 100, size.height);
	}
}

@end
