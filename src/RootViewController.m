#import "Compat.h"
#import "RootViewController.h"
#import "SockViewController.h"
#import "THtmlViewController.h"
#import "Setup.h"
#import "SetupColumns.h"
#import "GridCell.h"
#import "Column.h"
#import "Proc.h"
#import "ProcArray.h"
#import "AppDelegate.h"

#define NTSTAT_PREQUERY_INTERVAL	0.1

@implementation UIScrollView (AdjustInset)

-(UIEdgeInsets)realUIContentInset {
    if (@available(iOS 11.0, *)) {
        //UIEdgeInsets system = self.adjustedContentInset;
        //UIEdgeInsets user = self.contentInset;
        //return UIEdgeInsetsMake(system.top + user.top, system.left + user.left, system.bottom + user.bottom, system.right + user.right);
        return self.adjustedContentInset;
    } else {
        return self.contentInset;
    }
}

@end

@implementation RootViewController
{
	GridHeaderView *header;
	GridHeaderView *footer;
	UISearchBar *filter;
	PSProcArray *procs;
	NSTimer *timer;
	UILabel *statusLabel;
	NSArray *columns;
	PSColumn *sortColumn;
	PSColumn *filterColumn;
	BOOL sortDescending;
	BOOL fullScreen;
	CGFloat timerInterval;
	NSUInteger configId;
	NSString *configChange;
	pid_t selectedPid;
    UIUserInterfaceSizeClass lastHorizationWindowSizeClass;
    CGFloat lastHorizationWindowWidth;
}

- (void)popupMenuTappedItem:(NSInteger)item
{
	UIViewController* view = nil;
	switch (item) {
	case 0: view = [[SetupViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	case 1: view = [[SetupColsViewController alloc] initWithStyle:UITableViewStyleGrouped]; break;
	case 2: view = [[HtmlViewController alloc] initWithURL:@"guide" title:@"Quick Guide"]; break;
	case 3: view = [[HtmlViewController alloc] initWithURL:@"story" title:@"The Story"]; break;
	}
	if (view)
		[self.navigationController pushViewController:view animated:YES];
}

- (UINavigationController*)navigationController {
    if ([self.parentViewController isKindOfClass: [RootTabMaskController class]]) {
        return self.parentViewController.navigationController;
    } else {
        return [super navigationController];
    }
}

- (UINavigationItem *)navigationItem {
    if ([self.parentViewController isKindOfClass: [RootTabMaskController class]]) {
        return self.parentViewController.navigationItem;
    } else {
        return [super navigationItem];
    }
}

- (IBAction)hideShowNavBar:(UIGestureRecognizer *)gestureRecognizer
{
	if (!gestureRecognizer || gestureRecognizer.state == UIGestureRecognizerStateEnded) {
		fullScreen = !self.navigationController.navigationBarHidden;
		// This "scrolls" tableview so that it doesn't actually move when the bars disappear
		if (!fullScreen) {			// Show navbar & scrollbar (going out of fullscreen)
			[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
			[self.navigationController setNavigationBarHidden:NO animated:NO];
		}
		CGSize size = [UIApplication sharedApplication].statusBarFrame.size;
		CGFloat slide = MIN(size.width, size.height) +
			self.navigationController.navigationBar.frame.size.height +
			([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] ? self.tableView.sectionHeaderHeight : 0);
		CGPoint contentOffset = self.tableView.contentOffset;
		contentOffset.y += fullScreen ? -slide : slide;
		[self.tableView setContentOffset:contentOffset animated:NO];
		if (fullScreen) {			// Hide navbar & scrollbar (entering fullscreen)
			[self.navigationController setNavigationBarHidden:YES animated:NO];
			[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
		}
		[self.tableView reloadData];
//		[timer fire];
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
	bool isPhone = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;

//	self.wantsFullScreenLayout = YES;
	[self popupMenuWithItems:@[@"Settings", @"Columns", @"Quick Guide", @"About"] selected:-1 aligned:UIControlContentHorizontalAlignmentLeft];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIButtonBarHamburger"] style:UIBarButtonItemStylePlain
		target:self action:@selector(popupMenuToggle)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
		target:self action:@selector(refreshProcs:)];
	statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width - (isPhone ? 80 : 150), 40)];
	statusLabel.backgroundColor = [UIColor clearColor];
	self.navigationItem.leftBarButtonItems = @[self.navigationItem.leftBarButtonItem, [[UIBarButtonItem alloc] initWithCustomView:statusLabel]];

	UITapGestureRecognizer *twoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideShowNavBar:)];
	twoTap.numberOfTouchesRequired = 2;
	[self.tableView addGestureRecognizer:twoTap];

	filter = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0)];
	filter.autocapitalizationType = UITextAutocapitalizationTypeNone;
	filter.autocorrectionType = UITextAutocorrectionTypeNo;
	filter.spellCheckingType = UITextSpellCheckingTypeNo;
    [filter setBackgroundImage:[UIImage new]];
//	filter.returnKeyType = UIReturnKeyDone;
//	filter.showsCancelButton = YES;
//	filter.showsSearchResultsButton = NO;
	filter.delegate = self; 
	[filter sizeToFit];
    
    if (@available(iOS 13, *)) {
        self.tableView.backgroundColor = UIColor.systemBackgroundColor;
    } else {
        self.tableView.backgroundColor = [UIColor colorWithWhite:.75 alpha:1];
    }
    self.tableView.rowHeight = 44;
    self.tableView.sectionHeaderHeight = 23;
    self.tableView.sectionFooterHeight = 23;
	self.tableView.tableHeaderView = filter;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame: CGRectZero];

	self.tableView.sectionHeaderHeight = self.tableView.sectionHeaderHeight * 3 / 2;
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (@available(iOS 7, *)) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
//#endif
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		@"Columns" : @[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
		@"UpdateInterval" : @"1",
		@"FullWidthCommandLine" : @NO,
		@"ColorDiffs" : @YES,
		@"AutoJumpNewProcess" : @NO,
		@"FirstColumnStyle" : @"Bundle Identifier",
		@"ShowHeader" : @YES,
		@"ShowFooter" : @YES,
		@"ShortenPaths" : @YES,
		@"SortColumn" : @1,         @"SortDescending" : @NO,		// Main page (sort by pid)
		@"FilterColumn" : @0,
		@"ProcInfoMode" : @0,
		@"Mode0SortColumn" : @1001, @"Mode0SortDescending" : @NO,	// Summary (by initial column order)
		@"Mode1SortColumn" : @2000, @"Mode1SortDescending" : @NO,	// Threads (by thread id)
		@"Mode2SortColumn" : @3002, @"Mode2SortDescending" : @YES,	// FDs (backwards by type)
		@"Mode3SortColumn" : @4001, @"Mode3SortDescending" : @NO,	// Modules (by address)
	}];
	configChange = @"";
	configId = 0;
	selectedPid = -1;
	fullScreen = NO;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)filterText
{
	[procs filter:filterText column:filterColumn];
	[self.tableView reloadData];
	[footer updateSummaryWithColumns:columns procs:procs];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
	searchBar.placeholder = [NSString stringWithFormat:@"filter by %@ <tap another column>", filterColumn.fullname.lowercaseString];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
	searchBar.placeholder = [NSString stringWithFormat:@"filter by %@", filterColumn.fullname.lowercaseString];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	[searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	[filter resignFirstResponder];
}

- (void)preRefreshProcs:(NSTimer *)_timer
{
	// Time to query network statistics
	[procs.nstats query];
	// And update the view when statistics arrive
	if (timer.isValid)
		[timer invalidate];
	timer = [NSTimer scheduledTimerWithTimeInterval:NTSTAT_PREQUERY_INTERVAL target:self selector:@selector(refreshProcs:) userInfo:nil repeats:NO];
}

- (void)refreshProcs:(NSTimer *)_timer
{
	// Rearm the timer: this way the timer will wait for a full interval after each 'fire'
	if (timerInterval >= 0.1 + NTSTAT_PREQUERY_INTERVAL) {
		if (timer.isValid)
			[timer invalidate];
		timer = [NSTimer scheduledTimerWithTimeInterval:(timerInterval - NTSTAT_PREQUERY_INTERVAL) target:self selector:@selector(preRefreshProcs:) userInfo:nil repeats:NO];
	}
	// Do not refresh while the user is killing a process
	if (self.tableView.editing)
		return;
	[procs refresh];
	[procs sortUsingComparator:sortColumn.sort desc:sortDescending];
	[procs filter:filter.text column:filterColumn];
	[self.tableView reloadData];
	[footer updateSummaryWithColumns:columns procs:procs];
	// Status bar
// Also add: Uptime, CPU Freq, Cores, Cache L1/L2
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
//		statusLabel.text = [NSString stringWithFormat:@"Free: %.1f MB  CPU: %.1f%%",
//			(float)procs.memFree / 1024 / 1024,
//			(float)procs.totalCpu / 10];
//    } else {
//		statusLabel.text = [NSString stringWithFormat:@"Processes: %lu   Threads: %lu   Free: %.1f/%.1f MB   CPU: %.1f%%",
//			(unsigned long)procs.totalCount,
//			(unsigned long)procs.threadCount,
//			(float)procs.memFree / 1024 / 1024,
//			(float)procs.memTotal / 1024 / 1024,
//			(float)procs.totalCpu / 10];
//    }
    bool shortLabel;
    if (@available(iOS 8, *)) {
        UIUserInterfaceSizeClass sizeClass;
        if (self.view.window == nil) {
            sizeClass = [UIApplication sharedApplication].keyWindow.traitCollection.horizontalSizeClass;
        } else {
            sizeClass = self.view.window.traitCollection.horizontalSizeClass;
        }
        shortLabel = (sizeClass == UIUserInterfaceSizeClassCompact);
    } else {
        shortLabel = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
    }
    
    if (shortLabel) {
        statusLabel.frame = CGRectMake(statusLabel.frame.origin.x, statusLabel.frame.origin.y, self.tableView.frame.size.width - 80, 40);
        statusLabel.text = [NSString stringWithFormat:@"Free: %.1f MB  CPU: %.1f%%",
        (float)procs.memFree / 1024 / 1024,
        (float)procs.totalCpu / 10];
    } else {
        statusLabel.frame = CGRectMake(statusLabel.frame.origin.x, statusLabel.frame.origin.y, self.tableView.frame.size.width - 150, 40);
        statusLabel.text = [NSString stringWithFormat:@"Processes: %lu   Threads: %lu   Free: %.1f/%.1f MB   CPU: %.1f%%",
        (unsigned long)procs.totalCount,
        (unsigned long)procs.threadCount,
        (float)procs.memFree / 1024 / 1024,
        (float)procs.memTotal / 1024 / 1024,
        (float)procs.totalCpu / 10];
    }
	// Query network statistics, cause no one did it before.
	if (![_timer isKindOfClass:[NSTimer class]])
		[procs.nstats query];
	// First time refresh? Or returned from a sub-page.
	if (_timer == nil) {
		// We don't need info about new processes, they are all new :)
		[procs setAllDisplayed:ProcDisplayNormal];
		NSUInteger idx = NSNotFound;
		if (selectedPid != -1) {
			idx = [procs indexForPid:selectedPid];
			selectedPid = -1;
		}
		if (idx != NSNotFound && procs[idx].display != ProcDisplayTerminated) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
//#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
            if (@available(iOS 7, *)) {
                
            } else {
                [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0] animated:YES];
            }
//#endif
		}
	} else if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoJumpNewProcess"]) {
		// If there's a new/terminated process, scroll to it
		NSUInteger
			idx = [procs indexOfDisplayed:ProcDisplayStarted];
		if (idx == NSNotFound)
			idx = [procs indexOfDisplayed:ProcDisplayTerminated];
		if (idx != NSNotFound) {
			// Processes at the end of the list are in priority for scrolling!
			PSProc *last = procs[procs.count-1];
			if (last.display == ProcDisplayStarted || last.display == ProcDisplayTerminated)
				idx = procs.count-1;
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]
				atScrollPosition:UITableViewScrollPositionNone animated:YES];
		}
		// [self.tableView insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
		// [self.tableView deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:UITableViewRowAnimationAutomatic]
	}
}

- (void)sortHeader:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint loc = [gestureRecognizer locationInView:header];
	for (PSColumn *col in columns) {
		if (loc.x > col.width) {
			loc.x -= col.width;
			continue;
		}
		if (filter.isFirstResponder && !filter.text.length) {
			// Change filtering column
			filterColumn = col;
			[[NSUserDefaults standardUserDefaults] setInteger:col.tag forKey:@"FilterColumn"];
			[self searchBarTextDidEndEditing:filter];
		} else {
			// Change sorting column
			sortDescending = sortColumn == col ? !sortDescending : col.style & ColumnStyleSortDesc;
			[header sortColumnOld:sortColumn New:col desc:sortDescending];
			sortColumn = col;
			[[NSUserDefaults standardUserDefaults] setInteger:col.tag forKey:@"SortColumn"];
			[[NSUserDefaults standardUserDefaults] setBool:sortDescending forKey:@"SortDescending"];
			[timer fire];
		}
		break;
	}
}

- (void)scrollToBottom
{
	[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0]-1 inSection:0]
		atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)columnConfigChanged
{
	// When configId changes, all cells are reconfigured
	configId++;
	columns = [PSColumn psGetShownColumnsWithWidth:UIApplication.sharedApplication.keyWindow.bounds.size.width];
	// Find sort column and create table header
	filterColumn = [PSColumn psColumnWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"FilterColumn"]];
	[self searchBarTextDidEndEditing:filter];
	sortColumn = [PSColumn psColumnWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"SortColumn"]];
	if (!sortColumn) sortColumn = columns[0];
	sortDescending = [[NSUserDefaults standardUserDefaults] boolForKey:@"SortDescending"];
	header = [GridHeaderView headerWithColumns:columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionHeaderHeight)];
	footer = [GridHeaderView footerWithColumns:columns size:CGSizeMake(self.tableView.bounds.size.width, self.tableView.sectionFooterHeight)];
	[header sortColumnOld:nil New:sortColumn desc:sortDescending];
	[header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sortHeader:)]];
	[footer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollToBottom)]];
}

- (void)reappearAllView {
    // When major options change, process list is rebuilt from scratch
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    NSString *configCheck = [NSString stringWithFormat:@"%d-%@", [def boolForKey:@"ShortenPaths"], [def stringForKey:@"FirstColumnStyle"]];
    if (![configChange isEqualToString:configCheck]) {
        procs = [PSProcArray psProcArrayWithIconSize:self.tableView.rowHeight];
        configChange = configCheck;
    }
    [self columnConfigChanged];
    // Hide filter bar
    CGFloat minOffset = filter.frame.size.height - self.tableView.realUIContentInset.top;
    if (self.tableView.contentOffset.y < minOffset)
        self.tableView.contentOffset = CGPointMake(0, minOffset);
    // Refresh interval
    timerInterval = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
    [self refreshProcs:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.view.window != nil) {
        if (@available(iOS 8, *)) {
            if (lastHorizationWindowSizeClass != self.view.window.traitCollection.horizontalSizeClass || lastHorizationWindowWidth != self.view.bounds.size.width) {
                if (self.view.window.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
                    statusLabel.frame = CGRectMake(statusLabel.frame.origin.x, statusLabel.frame.origin.y, self.tableView.frame.size.width - 80, 40);
                    statusLabel.text = [NSString stringWithFormat:@"Free: %.1f MB  CPU: %.1f%%",
                    (float)procs.memFree / 1024 / 1024,
                    (float)procs.totalCpu / 10];
                } else {
                    statusLabel.frame = CGRectMake(statusLabel.frame.origin.x, statusLabel.frame.origin.y, self.tableView.frame.size.width - 150, 40);
                    statusLabel.text = [NSString stringWithFormat:@"Processes: %lu   Threads: %lu   Free: %.1f/%.1f MB   CPU: %.1f%%",
                    (unsigned long)procs.totalCount,
                    (unsigned long)procs.threadCount,
                    (float)procs.memFree / 1024 / 1024,
                    (float)procs.memTotal / 1024 / 1024,
                    (float)procs.totalCpu / 10];
                }
                lastHorizationWindowSizeClass = self.view.window.traitCollection.horizontalSizeClass;
                lastHorizationWindowWidth = self.view.bounds.size.width;
                [self reappearAllView];
            }
        }
    }
}


- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    if (@available(iOS 7, *)) {
        self.navigationController.navigationBar.barTintColor = nil;
    } else {
        self.navigationController.navigationBar.tintColor = nil;
    }
    [self reappearAllView];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	if (timer.isValid)
		[timer invalidate];
	header = nil;
	footer = nil;
	columns = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if ((fromInterfaceOrientation == UIInterfaceOrientationPortrait || fromInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) &&
		(self.interfaceOrientation == UIInterfaceOrientationPortrait || self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
		return;
	if ((fromInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || fromInterfaceOrientation == UIInterfaceOrientationLandscapeRight) &&
		(self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft || self.interfaceOrientation == UIInterfaceOrientationLandscapeRight))
		return;
	[self columnConfigChanged];
	[timer fire];
}

#pragma mark -
#pragma mark Table view data source

// Section header/footer will be used as a grid header/footer
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] && !fullScreen ? header : nil; }

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFooter"] && !fullScreen ? footer : nil; }

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowHeader"] && !fullScreen ? self.tableView.sectionHeaderHeight : 0; }

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{ return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowFooter"] && !fullScreen ? self.tableView.sectionFooterHeight : 0; }

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Data is acquired from PSProcArray
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return procs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	PSProc *proc = nil;
	if (indexPath.row < procs.count && columns && columns.count)
		proc = procs[indexPath.row];
	GridTableCell *cell = [tableView dequeueReusableCellWithIdentifier:[GridTableCell reuseIdWithIcon:proc.icon != nil]];
	if (cell == nil)
		cell = [GridTableCell cellWithIcon:proc.icon != nil];
	[cell configureWithId:configId columns:columns size:CGSizeMake(0, tableView.rowHeight)];
	if (proc)
		[cell updateWithProc:proc columns:columns];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	display_t display = ((PSProc *)procs[indexPath.row]).display;
    if (display == ProcDisplayTerminated) {
        if (@available(iOS 13, *)) {
            cell.backgroundColor = [UIColor colorWithDynamicProvider:^(UITraitCollection *collection) {
                if (collection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:0.5 green:0.12 blue:0.12 alpha:1];
                } else {
                    return [UIColor colorWithRed:1 green:0.7 blue:0.7 alpha:1];
                }
            }];
        } else {
            cell.backgroundColor = [UIColor colorWithRed:1 green:0.7 blue:0.7 alpha:1];
        }
    } else if (display == ProcDisplayStarted) {
        if (@available(iOS 13, *)) {
            cell.backgroundColor = [UIColor colorWithDynamicProvider:^(UITraitCollection *collection) {
                if (collection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:0.12 green:0.5 blue:0.12 alpha:1];
                } else {
                    return [UIColor colorWithRed:0.7 green:1 blue:0.7 alpha:1];
                }
            }];
        } else {
            cell.backgroundColor = [UIColor colorWithRed:0.7 green:1 blue:0.7 alpha:1];
        }
    } else if (indexPath.row & 1) {
		//cell.backgroundColor = [UIColor colorWithRed:.95 green:.95 blue:.95 alpha:1];
        if (@available(iOS 13, *)) {
            cell.backgroundColor = UIColor.secondarySystemBackgroundColor;
        } else {
            cell.backgroundColor = [UIColor colorWithRed:.95 green:.95 blue:.95 alpha:1];
        }
    } else {
		//cell.backgroundColor = [UIColor whiteColor];
        if (@available(iOS 13, *)) {
            cell.backgroundColor = UIColor.systemBackgroundColor;
        } else {
            cell.backgroundColor = [UIColor whiteColor];
        }
    }
}

- (void)tableView:(UITableView *)tableView sendSignal:(int)sig toProcessAtIndexPath:(NSIndexPath *)indexPath
{
	PSProc *proc = procs[indexPath.row];
	// task_for_pid(mach_task_self(), pid, &task)
	// task_terminate(task)
	if (kill(proc.pid, sig)) {
		NSString *msg = [NSString stringWithFormat:@"Error %d while terminating app", errno];
		[[[UIAlertView alloc] initWithTitle:proc.name message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
	}
	// Refresh immediately to show process termination
	tableView.editing = NO;
	[timer performSelector:@selector(fire) withObject:nil afterDelay:.1f];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"KILL";
}

- (NSString *)tableView:(UITableView *)tableView titleForSwipeAccessoryButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"TERM";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
		[self tableView:tableView sendSignal:SIGKILL toProcessAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView swipeAccessoryButtonPushedForRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self tableView:tableView sendSignal:SIGTERM toProcessAtIndexPath:indexPath];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	BOOL anim = NO;
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	// Shitty bug in iOS 7
    if (@available(iOS 7, *)) {
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_8_0) {
            anim = YES;
        }
        anim = true;
    }
//#endif
	if (filter.isFirstResponder)
		[filter resignFirstResponder];
	// Return from fullscreen, or there's no way back ;)
	if (fullScreen)
		[self hideShowNavBar:nil];
	PSProc *proc = procs[indexPath.row];
	selectedPid = proc.pid;
	[self.navigationController pushViewController:[[SockViewController alloc] initWithProc:proc] animated:anim];
}

#pragma mark -
#pragma mark Memory management

- (void)viewDidUnload
{
	if (timer.isValid)
		[timer invalidate];
	statusLabel = nil;
	header = nil;
	footer = nil;
	sortColumn = nil;
	filterColumn = nil;
	procs = nil;
	columns = nil;
	[super viewDidUnload];
}

- (void)dealloc
{
	if (timer.isValid)
		[timer invalidate];
}

@end
