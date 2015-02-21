#import "About.h"
#import <MessageUI/MessageUI.h>

@interface WebViewController : UIViewController
@end

@implementation WebViewController

- (void)loadView
{
	self.navigationItem.title = @"Donate using PayPal";
	UIWebView* webView = [[UIWebView alloc] initWithFrame:CGRectZero];
//	NSString *urlString = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)text, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
	[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CSFS43BNNZYV6"]]];
	self.view = webView;
	[webView release];
}

@end


@interface AboutViewController()
@property (retain) NSString *aboutText;
@end

@implementation AboutViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.title = @"The Story";
	self.aboutText =
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
		"thing I would really prefer is killing zombies, but not sure if that fits with the iOS philosophy."//\n"
	;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.tableView reloadData];
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

-(CGFloat)cellsMargin
{
	CGFloat widthTable = self.tableView.bounds.size.width;
//	if (isPhone)              return (10.0f);
	if (widthTable <= 400.0f) return (10.0f);
	if (widthTable <= 546.0f) return (31.0f);
	if (widthTable >= 720.0f) return (45.0f);
	return (31.0f + ceilf((widthTable - 547.0f)/13.0f));
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section)
		return UITableViewAutomaticDimension;
	CGSize maximumSize = CGSizeMake(tableView.contentSize.width - [self cellsMargin] * 2 - 20, 10000);
	CGSize expectedSize = [self.aboutText sizeWithFont:[UIFont systemFontOfSize:16.0] constrainedToSize:maximumSize lineBreakMode:NSLineBreakByWordWrapping];
	return expectedSize.height + 25;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"About"];
		if (cell == nil)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"About"];
		if (indexPath.row == 0)
			cell.textLabel.text = @"Donate via PayPal, if you like this stuff";
		else
			cell.textLabel.text = @"Email developer";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	} else {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AboutBig"];
		if (cell == nil)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AboutBig"];
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.textLabel.font = [UIFont systemFontOfSize:16.0];
		cell.textLabel.text = self.aboutText;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
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
		[emailView setToRecipients:@[@"domo@rambler.ru"]];
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

- (void)dealloc
{
	[_aboutText release];
	[super dealloc];
}

@end
