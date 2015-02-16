#import "About.h"

@implementation AboutViewController

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
	return @"The Story";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	int numberOfLines = 30;
	return  (44.0 + (numberOfLines - 1) * 19.0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"About"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"About"];
	cell.textLabel.numberOfLines = 0;
	cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
	cell.textLabel.font = [UIFont systemFontOfSize:16.0];
	cell.textLabel.text =
		@"Hello, friends!\n\n"
		"This text should clarify some questionable concepts implemented in CocoaTop, the ideas behind those concepts, "
		"and the idea behind the application itself. Also, it should be a fun read, at least for some ;)\n\n"
		"Before we begin I would like to thank Luis Finke for making miniCode (available in Cydia) - a nice alternative "
		"to XCode that became an IDE for my first iOS app, which is also my first Objective-C app.\n\n"
		"Now, you could say that the purpose of CocoaTop is to replace the original 'terminal' top - but it is not. "
		"First of all, the UNIX terminal is a thing in itself: every iPad user has to have a terminal installed, "
		"otherwise (s)he can be mistaken for a dork, or worse - a humanitarian. Also, top executed on an iPad "
		"always attracts people's attention. So the idea behind this app is this: I wanted to create something nice, "
		"gaining knowledge in the process. If you find it useful, well, you're in luck!\n\n"
		"Now, on to the details:\n\n"
		"1. CPU usage sums up not to 100% but to 100*cores %. Moreover, it can actually exceed this value, and it surely will "
		"when the cores are doing the real stuff: protein folding and shit like that. This is due to a scheduling policy "
		"of the Mach Kernel, which is called decay-usage scheduling. When a thread acquires CPU time, its priority is continually "
		"being depressed: this ensures short response times of interactive jobs, which do not always have a high initial priority. "
		"The decayed CPU usage of a running thread increases in a linearly proportional fashion with CPU time obtained, and is "
		"periodically divided by the decay factor, which is a constant larger than one. Thus, the Mach CPU utilization of "
		"the process is a decaying average over up to a minute of previous (real) time. Since the time base over which this is "
		"computed varies (since processes may be very young) it is possible for the sum of all %cpu fields to exceed 100%. "
		"And this is exactly why Android sucks.\n\n"
		"1. Number one again? Allright. Processes and Mach tasks are different things. Here's why...\n\n"
		"2. There's no such thing as a running process, because it is the threads that run, not processes. So why is there a "
		"'Process running' state? Well, this is taken from the source code of top.\n"
	;
	return cell;
}
// Mac OS X and iOS internals
// Mach tasks vs. processes

@end
