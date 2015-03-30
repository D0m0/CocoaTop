#import "About.h"
#import <MessageUI/MessageUI.h>

CGFloat cellMargin(UITableView *tableView)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	return 15.0f;
#else
	CGFloat widthTable = tableView.bounds.size.width;
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) return 10.0f;
	if (widthTable <= 400.0f) return 10.0f;
	if (widthTable <= 546.0f) return 31.0f;
	if (widthTable >= 720.0f) return 45.0f;
	return 31.0f + ceilf((widthTable - 547.0f)/13.0f);
#endif
}

CGFloat cellOrigin(UITableView *tableView)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
	return 10.0f;
#else
	return cellMargin(tableView);
#endif
}

CGFloat cellWidth(UITableView *tableView)
{
	CGFloat width = tableView.frame.size.width - cellMargin(tableView) * 2;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
	width -= 20;
#endif
	return width;
}

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
@property (retain) UILabel *aboutLabel;
@end

@implementation AboutViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.title = @"The Story";
	self.aboutLabel = [UILabel new];
	self.aboutLabel.font = [UIFont systemFontOfSize:16.0];
	self.aboutLabel.backgroundColor = [UIColor clearColor];
	self.aboutLabel.numberOfLines = 0;
	self.aboutLabel.lineBreakMode = NSLineBreakByWordWrapping;
	self.aboutLabel.text = @"Hello, friends!\n\n"
		"This text should clarify some questionable concepts implemented in CocoaTop, the ideas behind those concepts, "
		"and the idea behind the application itself. Also, it should be a fun read, at least for some ;)\n\n"
		"Before we begin I would like to thank Luis Finke for making miniCode (available in Cydia) \u2014 a nice alternative "
		"to XCode that became an IDE for my first iOS app, which is also my first Objective C app. (Hey, if you think I "
		"typed the whole thing on the iPad, you're wrong. I even used Theos, goddamit, okay! But that's not the point!\n\n"
		"Now, you could say that the purpose of CocoaTop is to replace the original terminal 'top' \u2014 but it is not. "
		"First of all, the UNIX terminal is a thing in itself: every iPad user has to have a terminal installed, "
		"otherwise (s)he can be mistaken for a dork, or worse \u2014 a humanitarian. Also, 'top' executed on an iPad "
		"always attracts people's attention. So the idea behind CocoaTop is this: I wanted to create something nice, "
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
		"very young) it is possible for the sum of all %CPU fields to exceed 100%. And this is why Android sucks. Also, because "
		"of Java, which isn't bad by itself, but... the mobile world?\n\n"
		"\u2605 Everyone knows about processes, but what about Mach tasks? These are actually different things. In fact, it is "
		"technically possible to create a Mach task without a BSD process. A Mach task can actually be created without threads "
		"and memory (ah, the benefits of The Microkernel, my love). Mach tasks do not have parent-child relationships, those are "
		"implemented at the BSD level. This implies that BSD (or, generally, POSIX) has more morale, but not really. In UNIX, it "
		"is actually the norm for the parent to outlive its children. Furthermore, a parent actually expects their children to die, "
		"otherwise they rise as zombies. This is why I love pure microkernels.\n\n"
		"\u2605 You can kill processes by swiping to the left, but this seems cruel. One thing I would really prefer is killing "
		"zombies, but not sure if that fits with the iOS philosophy.\n\n"
		"\u2605 There's no such thing as a running process, because it is the threads that run, not processes. So why is there a "
		"'Process running' state? Well, this is done to simplify the output, and actually taken from the original 'top' source "
		"code. Most process states are calculated from thread states using a simple rule of precedence: i.e. if at least one thread "
		"is running, the process state is presumed 'R', and so on. The complete list can be seen in the previous pane.\n\n"
		"\u2605 There is also a column called 'Mach Actual Threads Priority'. What it actually contains is the highest priority of "
		"a thread within the process. This is also the way original 'top' works. Also, there are several scheduling schemes "
		"supported by Mach, but only one of them is actually used in iOS \u2014 'Time Sharing'. The other two, 'Round-Robin' "
		"and 'FIFO', will be marked in this column using prefixes R: and F: respectively, but I've never seen them. I added "
		"those marks out of curiosity - write me a letter.\n\n"
		"\u2605 Apple tightens up security with each new version of iOS, so CocoaTop can no longer show details about task 0 "
		"(the kernel task) on iOS\u00A08. You can still enjoy this data if you have iOS\u00A07! Actually, the iOS could be considered the "
		"most secure public platform of all times, only if it wasn't so stuffed with backdoors, at least in v.7 ;) Anyways, "
		"it's better than the other non-evil company ;)\n\n"
		"\u2605 There's a 'Mach Task Role' column which actually shows the assigned role for GUI apps, like in OS\u00A0X. I noticed "
		"this works only on iOS\u00A08."//\n"
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0)
		return [self.aboutLabel sizeThatFits:CGSizeMake(cellWidth(tableView), MAXFLOAT)].height + 25;
	return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;
	if (indexPath.section) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"About"];
		if (cell == nil)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"About"];
		if (indexPath.row == 0)
			cell.textLabel.text = @"Donate via PayPal, if you like this stuff";
		else
			cell.textLabel.text = @"Email for feedback and suggestions";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	} else {
		cell = [tableView dequeueReusableCellWithIdentifier:@"AboutBig"];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AboutBig"];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			[cell.contentView addSubview:self.aboutLabel];
		}
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0) {
		CGFloat width = cellWidth(tableView);
		self.aboutLabel.frame = CGRectMake(cellOrigin(tableView), 12, width, MAXFLOAT);
		[self.aboutLabel sizeToFit];
		self.aboutLabel.frame = CGRectMake(cellOrigin(tableView), 12, width, self.aboutLabel.frame.size.height);
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1 && indexPath.row == 0) {
		WebViewController* webView = [WebViewController new];
		[self.navigationController pushViewController:webView animated:YES];
		[webView release];
	}
	if (indexPath.section == 1 && indexPath.row == 1) {
		if ([MFMailComposeViewController canSendMail]) {
			MFMailComposeViewController* emailView = [MFMailComposeViewController new];
			emailView.mailComposeDelegate = self;
			[emailView setToRecipients:@[@"domo@rambler.ru"]];
			[emailView setSubject:@"CocoaTop feedback"];
			[self presentViewController:emailView animated:YES completion:nil];
			[emailView release];
			[tableView deselectRowAtIndexPath:indexPath animated:NO];
		} else {
			UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:@"Send Mail" message:@"Your e-mail is not configured on this device"
				delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
			[alertView show];
			[tableView deselectRowAtIndexPath:indexPath animated:NO];
		}
	}
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc
{
	[_aboutLabel release];
	[super dealloc];
}

@end
