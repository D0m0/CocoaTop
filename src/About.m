#import "About.h"
#import <MessageUI/MessageUI.h>

@interface WebViewController : UIViewController
@end

@implementation WebViewController

- (void)loadView
{
	self.navigationItem.title = @"Donate using PayPal";
	UIWebView* webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://paypal.com/"]]];
	self.view = webView;
	[webView release];
}

/*
NSString *address = @"http://m.forrent.com/search.php?";
NSString *params1 = @"address=92115&beds=&baths=&price_to=0";
// URL encode the problematic part of the url.
NSString *params2 = @"#{%22lat%22:%220%22,%22lon%22:%220%22,%22distance%22:%2225%22,%22seed%22:%221622727896%22,%22is_sort_default%22:%221%22,%22sort_by%22:%22%22,%22page%22:%221%22,%22startIndex%22:%220%22,%22address%22:%2292115%22,%22beds%22:%22%22,%22baths%22:%22%22,%22price_to%22:%220%22}";
params2 = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)text, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);;
// Build the url and loadRequest
NSString *urlString = [NSString stringWithFormat:@"%@%@%@",address,params1,params2];
[self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://paypal.com/"]]];
*/
@end


@implementation AboutViewController

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationItem.title = @"The Story";
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
	return section ? @"Donate" : @"About CocoaTop";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return section ? 2 : 1;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section)
		return 44;
	CGFloat height = 44 + 19 * /*numberOfLines:*/ 50;
	return (tableView.frame.size.height > tableView.frame.size.width) ? height * 1.3 : height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"About"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"About"];
	if (indexPath.section) {
		if (indexPath.row == 0)
			cell.textLabel.text = @"Donate via PayPal, if you like this stuff";
		else
			cell.textLabel.text = @"Email developer";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	} else {
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.textLabel.font = [UIFont systemFontOfSize:16.0];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text =
			@"Hello, friends!\n\n"
			"This text should clarify some questionable concepts implemented in CocoaTop, the ideas behind those concepts, "
			"and the idea behind the application itself. Also, it should be a fun read, at least for some ;)\n\n"
			"Before we begin I would like to thank Luis Finke for making miniCode (available in Cydia) \u2014 a nice alternative "
			"to XCode that became an IDE for my first iOS app, which is also my first Objective C app.\n\n"
			"Now, you could say that the purpose of CocoaTop is to replace the original 'terminal' top \u2014 but it is not. "
			"First of all, the UNIX terminal is a thing in itself: every iPad user has to have a terminal installed, "
			"otherwise (s)he can be mistaken for a dork, or worse \u2014 a humanitarian. Also, top executed on an iPad "
			"always attracts people's attention. So the idea behind this app is this: I wanted to create something nice, "
			"gaining knowledge in the process. If you find it useful, well, you're in luck!\n\n"
			"Ok, on to the fun facts:\n\n"
			"\u2605 CPU usage sums up not to 100% but to cores\u00D7100%. Moreover, it can actually exceed this value, and it surely will "
			"when the cores are doing the real stuff: protein folding and shit like that. CPU exceeds 100% not for your amusement, "
			"but due to a scheduling policy of the Mach Kernel, which is called decay-usage scheduling. When a thread acquires CPU "
			"time, its priority is continually being depressed: this ensures short response times of interactive jobs, which "
			"do not always have a high initial priority, especially on weaker mobile platforms. The decayed CPU usage of a running "
			"thread increases in a linearly proportional fashion with CPU time obtained, and is periodically divided by the decay "
			"factor, which is a constant larger than one. Thus, the Mach CPU utilization of the process is a decaying average over "
			"up to a minute of previous (real) time. Since the time base over which this is computed varies (since processes may be "
			"very young) it is possible for the sum of all %CPU fields to exceed 100%. And this is exactly why Android sucks.\n\n"
			"\u2605 Processes and Mach tasks are different things. In fact, it is technically possible to "
			"create a Mach task without a BSD process. A Mach task can actually be created without threads and memory. Mach tasks "
			"do not have parent-child relationships, those are implemented at the BSD level. "
			"In UNIX, it is actually the norm for the parent to outlive its children. A parent can fork (or posix_spawn) children, "
			"and actually expects them to die. UNIX processes, unlike some humans, have a very distinct and clear meaning in life \u2014 "
			"to run, and then return a single integer value.\n\n"
			"\u2605 There's no such thing as a running process, because it is the threads that run, not processes. So why is there a "
			"'Process running' state? Well, this is taken from the source code of top.\n\n"
			"\u2605 There is also a column called 'Mach Actual Threads Priority'. What it actually contains is the highest priority of "
			"a thread within the process. This is also the way original top works. Also, there are several scheduling schemes "
			"supported by Mach, but only one of them is actually used in iOS \u2014 'Time Sharing'. The other two \u2014 'Round-Robin' "
			"and 'FIFO' will be indicated in this column using prefixes R: and F: respectively. I added those out of curiosity.\n\n"
			"\u2605 Apple tightens up security with each new version of iOS, so CocoaTop can no longer show details about task 0 "
			"(the kernel task) on iOS 8. You can still enjoy this data if you have iOS 7!\n\n"
			"\u2605 I didn't make an option to kill processes. This seems cruel. But, I'll think about it in later versions. One "
			"thing I would really prefer is killing zombies, but not sure if that fits with the iOS philosophy.\n"
		;
	}
	return cell;
}
// Mac OS X and iOS internals
// Mach tasks vs. processes

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1 && indexPath.row == 0) {
		WebViewController* webView = [[WebViewController alloc] init];
		[self.navigationController pushViewController:webView animated:YES];
		[webView release];
	}
	if (indexPath.section == 1 && indexPath.row == 1) {
		MFMailComposeViewController* emailView = [[MFMailComposeViewController alloc] init];
		emailView.mailComposeDelegate = self;
		[emailView setToRecipients:@[@"domeek@gmail.com"]];
		[emailView setSubject:@"CocoaTop feedback"];
		[self presentViewController:emailView animated:YES completion:nil];
		[emailView release];
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
