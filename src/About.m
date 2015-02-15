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

- (CGFloat) tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	int numberOfLines = 22;
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
		"and the idea behind the application itself. Also, it should be a fun read for some of you ;)\n\n"
		"Before we begin I would like to thank ... for making miniCode - a nice alternative to XCode that became an IDE "
		"for my first iOS app, which is also my first Objective-C app.\n\n"
		"1. CPU usage sums up not to 100% but to 100*cores %. Moreover, it can actually exceed this value ;)\n"
		"2. Process flags will surely be deciphered in future versions, but for now here's the full list:\n"
		"	0x00000001	P_ADVLOCK	\tProcess may hold POSIX adv. lock\n"
		"	0x00000002	P_CONTROLT	\tHas a controlling terminal\n"
		"	0x00000004	P_LP64		\t\tProcess is LP64\n"
		"	0x00000008	P_NOCLDSTOP	No SIGCHLD when children stop\n"
		"	0x00000010	P_PPWAIT	\t\tParent waiting for chld exec/exit\n"
		"	0x00000020	P_PROFIL	\t\tHas started profiling\n"
		"	0x00000040	P_SELECT	\t\tSelecting; wakeup/waiting danger\n"
		"	0x00000080	P_CONTINUED	\tProcess was stopped and continued\n"
		"	0x00000100	P_SUGID		\tHas set privileges since last exec\n"
	;
	return cell;
}
// Mac OS X and iOS internals

// Mach tasks vs. processes

	//"DZRUSITH?";
	//if (proc.nice < 0)
	//	*pst++ = L'\u25B4';	// ^
	//else if (proc.nice > 0)
	//	*pst++ = L'\u25BE';	// v
	//if (proc.flags & P_TRACED)
	//	*pst++ = 't';
	//if (proc.flags & P_WEXIT && proc.state != 1)
	//	*pst++ = 'z';
	//if (proc.flags & P_PPWAIT)
	//	*pst++ = 'w';
	//if (proc.flags & P_SYSTEM)
	//	*pst++ = 'K';

//#define	P_SYSTEM	0x00000200	/* Sys proc: no sigs, stats or swap */
//#define	P_TIMEOUT	0x00000400	/* Timing out during sleep */
//#define	P_TRACED	0x00000800	/* Debugged process being traced */
//
//#define	P_DISABLE_ASLR	0x00001000	/* Disable address space layout randomization */
//#define	P_WEXIT		0x00002000	/* Working on exiting */
//#define	P_EXEC		0x00004000	/* Process called exec. */
//
///* Should be moved to machine-dependent areas. */
//#define	P_OWEUPC	0x00008000	/* Owe process an addupc() call at next ast. */
//
//#define	P_AFFINITY	0x00010000	/* xxx */
//#define	P_TRANSLATED	0x00020000	/* xxx */
//#define	P_CLASSIC	P_TRANSLATED	/* xxx */
//
///*
//#define	P_FSTRACE	0x10000	/ * tracing via file system (elsewhere?) * /
//#define	P_SSTEP		0x20000	/ * process needs single-step fixup ??? * /
//*/
//
//#define	P_DELAYIDLESLEEP 0x00040000	/* Process is marked to delay idle sleep on disk IO */
//#define	P_CHECKOPENEVT 	0x00080000	/* check if a vnode has the OPENEVT flag set on open */
//
//#define	P_DEPENDENCY_CAPABLE	0x00100000	/* process is ok to call vfs_markdependency() */
//#define	P_REBOOT	0x00200000	/* Process called reboot() */
//#define	P_TBE		0x00400000	/* Process is TBE */
//#define	P_RESV7		0x00800000	/* (P_SIGEXC)signal exceptions */
//
//#define	P_THCWD		0x01000000	/* process has thread cwd  */
//#define	P_RESV9		0x02000000	/* (P_VFORK)process has vfork children */
//#define	P_RESV10 	0x04000000	/* used to be P_NOATTACH */
//#define	P_RESV11	0x08000000	/* (P_INVFORK) proc in vfork */
//
//#define	P_NOSHLIB	0x10000000	/* no shared libs are in use for proc */
//					/* flag set on exec */
//#define	P_FORCEQUOTA	0x20000000	/* Force quota for root */
//#define	P_NOCLDWAIT	0x40000000	/* No zombies when chil procs exit */
//#define	P_NOREMOTEHANG	0x80000000	/* Don't hang on remote FS ops */

@end
