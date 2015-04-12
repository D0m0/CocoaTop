#import "Column.h"
#import <pwd.h>
#import <grp.h>
#import <sys/stat.h>

@implementation PSColumn

NSString *psProcessStateString(PSProc *proc)
{
	static const char states[] = PROC_STATE_CHARS;
	unichar st[8], *pst = st;

	*pst++ = states[proc.state];
	if (proc.nice < 0)
		*pst++ = L'\u25B2';	// ^
	else if (proc.nice > 0)
		*pst++ = L'\u25BC';	// v
	if (proc.flags & P_TRACED)
		*pst++ = 't';
	if (proc.flags & P_WEXIT && proc.state != 1)
		*pst++ = 'z';
	if (proc.flags & P_PPWAIT)
		*pst++ = 'w';
	if (proc.flags & P_SYSTEM)
		*pst++ = 'K';
	if (proc->basic.suspend_count > 0)
		*pst++ = 'B';
	return [NSString stringWithCharacters:st length:(pst - st)];
}

NSString *psTaskRoleString(PSProc *proc)
{
	switch (proc.role) {
	case TASK_RENICED:					return @"Reniced";
	case TASK_UNSPECIFIED:				return @"-";
	case TASK_FOREGROUND_APPLICATION:	return @"Foreground";
	case TASK_BACKGROUND_APPLICATION:	return @"Background";
	case TASK_CONTROL_APPLICATION:		return @"Controller";
	case TASK_GRAPHICS_SERVER:			return @"GfxServer";
	case TASK_THROTTLE_APPLICATION:		return @"Throttle";
	case TASK_NONUI_APPLICATION:		return @"Inactive";
	case TASK_DEFAULT_APPLICATION:		return @"Default";
	default:							return @"Unknown";
	}
}

NSString *psProcessTty(PSProc *proc)
{
	char *ttname = 0;
	if (proc.tdev != NODEV)
		ttname = devname(proc.tdev, S_IFCHR);
	return [NSString stringWithCString:(ttname ? ttname : "??") encoding:NSASCIIStringEncoding];
}

NSString *psSystemUptime()
{
	struct timeval boottime;
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    size_t size = sizeof(boottime);
    time_t uptime;
	time(&uptime);
    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0) {
		uptime -= boottime.tv_sec;
		return [NSString stringWithFormat:@"%ldd %ld:%02ld:%02ld", uptime/60/60/24, (uptime/60/60) % 24, (uptime/60) % 60, uptime % 60];
	} else
		return @"-";
}

+ (NSArray *)psGetAllColumns
{
	static NSArray *allColumns;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		allColumns = [@[
		[PSColumn psColumnWithName:@"Command line" descr:@"Command line" align:NSTextAlignmentLeft width:170 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return proc.name; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"Total processes: %u", procs.count]; }],
		[PSColumn psColumnWithName:@"PID" descr:@"Process ID" align:NSTextAlignmentRight width:50 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.pid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pid - b.pid; } summary:nil],
		[PSColumn psColumnWithName:@"PPID" descr:@"Parent PID" align:NSTextAlignmentRight width:50 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ppid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ppid - b.ppid; } summary:nil],
		[PSColumn psColumnWithName:@"%" descr:@"%CPU Usage" align:NSTextAlignmentRight width:50 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return !proc.pcpu ? @"-" : [NSString stringWithFormat:@"%.1f", (float)proc.pcpu / 10]; }	// p->p_pctcpu / 1.05    - decay 95% in 60 seconds
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pcpu - b.pcpu; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%.1f%%", (float)procs.totalCpu / 10]; }],
		[PSColumn psColumnWithName:@"Time" descr:@"Process Time" align:NSTextAlignmentRight width:75 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u:%02u.%02u", proc.ptime / 6000, (proc.ptime / 100) % 60, proc.ptime % 100]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ptime - b.ptime; }
			summary:^NSString*(PSProcArray* procs) { return psSystemUptime(); }],
		[PSColumn psColumnWithName:@"S" descr:@"Mach Task State" align:NSTextAlignmentLeft width:30 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return psProcessStateString(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.state == b.state ? b->basic.suspend_count - a->basic.suspend_count : a.state - b.state; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%d/%d", procs.runningCount, procs.coresCount]; }],
		[PSColumn psColumnWithName:@"Flags" descr:@"Raw Process Flags (Hex)" align:NSTextAlignmentLeft width:70 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%08X", proc.flags]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [[NSNumber numberWithUnsignedInt:a.flags] compare:[NSNumber numberWithUnsignedInt:b.flags]]; } summary:nil],
		[PSColumn psColumnWithName:@"RMem" descr:@"Resident Memory Usage" align:NSTextAlignmentRight width:70 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return !proc->basic.resident_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.resident_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->basic.resident_size - b->basic.resident_size; }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memUsed countStyle:NSByteCountFormatterCountStyleMemory]; }],
		[PSColumn psColumnWithName:@"VSize" descr:@"Virtual Address Space Usage" align:NSTextAlignmentRight width:70 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return !proc->basic.virtual_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.virtual_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->basic.virtual_size - b->basic.virtual_size; }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memTotal countStyle:NSByteCountFormatterCountStyleMemory]; }],
		[PSColumn psColumnWithName:@"User" descr:@"User Id" align:NSTextAlignmentLeft width:80 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:user_from_uid(proc.uid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.uid - b.uid; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@" mobile: %d", procs.mobileCount]; }],
		[PSColumn psColumnWithName:@"Group" descr:@"Group Id" align:NSTextAlignmentLeft width:80 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:group_from_gid(proc.gid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.gid - b.gid; } summary:nil],
		[PSColumn psColumnWithName:@"TTY" descr:@"Terminal" align:NSTextAlignmentLeft width:65 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return psProcessTty(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.tdev - b.tdev; } summary:nil],
		[PSColumn psColumnWithName:@"Thr" descr:@"Thread Count" align:NSTextAlignmentRight width:40 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.threads]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.threads - b.threads; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.threadCount]; }],
		[PSColumn psColumnWithName:@"Ports" descr:@"Mach Ports" align:NSTextAlignmentRight width:50 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ports]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ports - b.ports; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.portCount]; }],
		[PSColumn psColumnWithName:@"Mach" descr:@"Mach System Calls" align:NSTextAlignmentRight width:52 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_mach - proc->events_prev.syscalls_mach]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a->events.syscalls_mach - a->events_prev.syscalls_mach) - (b->events.syscalls_mach - b->events_prev.syscalls_mach); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.machCalls]; }],
		[PSColumn psColumnWithName:@"BSD" descr:@"BSD System Calls" align:NSTextAlignmentRight width:52 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_unix - proc->events_prev.syscalls_unix]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a->events.syscalls_unix - a->events_prev.syscalls_unix) - (b->events.syscalls_unix - b->events_prev.syscalls_unix); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.unixCalls]; }],
		[PSColumn psColumnWithName:@"CSw" descr:@"Context Switches" align:NSTextAlignmentRight width:52 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.csw - proc->events_prev.csw]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a->events.csw - a->events_prev.csw) - (b->events.csw - b->events_prev.csw); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.switchCount]; }],
		[PSColumn psColumnWithName:@"Prio" descr:@"Mach Actual Threads Priority" align:NSTextAlignmentLeft width:42 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%@%u", 	proc->basic.policy == POLICY_RR ? @"R:" : proc->basic.policy == POLICY_FIFO ? @"F:" : @"", proc.prio]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.prio - b.prio; } summary:nil],
		[PSColumn psColumnWithName:@"BPri" descr:@"Base Process Priority" align:NSTextAlignmentLeft width:42 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.priobase]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.priobase - b.priobase; } summary:nil],
		[PSColumn psColumnWithName:@"Nice" descr:@"Process Nice Value" align:NSTextAlignmentRight width:42 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%d", proc.nice]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.nice - b.nice; } summary:nil],
		[PSColumn psColumnWithName:@"Role" descr:@"Mach Task Role" align:NSTextAlignmentLeft width:75 sortDesc:NO monoFont:NO
			data:^NSString*(PSProc *proc) { return psTaskRoleString(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a.role + (a.role <= 0 ? 50 : 0)) - (b.role + (b.role <= 0 ? 50 : 0)); }
			summary:^NSString*(PSProcArray* procs) { return procs.guiCount ? [NSString stringWithFormat:@" UIApps: %d", procs.guiCount] : @"   -"; }],
		[PSColumn psColumnWithName:@"MSent" descr:@"Mach Messages Sent" align:NSTextAlignmentRight width:70 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_sent]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->events.messages_sent - b->events.messages_sent; } summary:nil],
		[PSColumn psColumnWithName:@"MRecv" descr:@"Mach Messages Received" align:NSTextAlignmentRight width:70 sortDesc:YES monoFont:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_received]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->events.messages_received - b->events.messages_received; } summary:nil],
		] retain];
		int i = 1;
		for (PSColumn *col in allColumns) col.tag = i++;
	});
	return allColumns;
}

+ (NSMutableArray *)psGetShownColumnsWithWidth:(NSUInteger *)width
{
	NSArray *columnOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Columns"];
	NSArray *cols = [PSColumn psGetAllColumns];
	NSMutableArray *shownCols = [NSMutableArray array];
	// Sanity check
	if (columnOrder.count == 0)
		columnOrder = @[@0, @1, @2, @3, @6, @7, @8];
	for (NSNumber* order in columnOrder)
		if (order.unsignedIntegerValue < cols.count) {
			PSColumn *col = cols[order.unsignedIntegerValue];
			if (*width < col.width) break;
			[shownCols addObject:col];
			*width -= col.width;
		}
	*width += ((PSColumn *)shownCols[0]).width;
	return shownCols;
}

+ (NSArray *)psGetTaskColumns:(NSInteger)kind
{
	static NSArray *openfilesColumns;
	static NSArray *modulesColumns;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		openfilesColumns = [@[
		[PSColumn psColumnWithName:@"Open file/socket" descr:@"" align:NSTextAlignmentLeft width:220 sortDesc:NO monoFont:NO
			data:^NSString*(PSSock *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"FD" descr:@"" align:NSTextAlignmentRight width:50 sortDesc:NO monoFont:NO
			data:^NSString*(PSSock *sock) { return [NSString stringWithFormat:@"%X", sock.fd]; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return a.fd - b.fd; } summary:nil],
		[PSColumn psColumnWithName:@"Type" descr:@"" align:NSTextAlignmentLeft width:50 sortDesc:NO monoFont:NO
			data:^NSString*(PSSock *sock) { return sock.stype; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return [a.stype caseInsensitiveCompare:b.stype]/*a.type - b.type*/; } summary:nil],
		] retain];
		modulesColumns = [@[
		[PSColumn psColumnWithName:@"Mapped module" descr:@"" align:NSTextAlignmentLeft width:220 sortDesc:NO monoFont:NO
			data:^NSString*(PSSock *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"Addr" descr:@"" align:NSTextAlignmentRight width:90 sortDesc:NO monoFont:YES
			data:^NSString*(PSSock *sock) { return [NSString stringWithFormat:@"%llX", sock.addr]; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return a.addr == b.addr ? 0 : a.addr > b.addr ? 1 : -1; } summary:nil],
//		[PSColumn psColumnWithName:@"End" descr:@"" align:NSTextAlignmentRight width:90 sortDesc:NO monoFont:YES
//			data:^NSString*(PSSock *sock) { return sock.addrend == sock.addr ? @"-" : [NSString stringWithFormat:@"%llX", sock.addrend]; }
//			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return a.addrend == b.addrend ? 0 : a.addrend > b.addrend ? 1 : -1; } summary:nil],
		[PSColumn psColumnWithName:@"Inode" descr:@"" align:NSTextAlignmentLeft width:80 sortDesc:NO monoFont:NO
			data:^NSString*(PSSock *sock) { return sock.dev && sock.ino ? [NSString stringWithFormat:@"%u,%u %u", sock.dev >> 24, sock.dev & 0xffffff, sock.ino] : @"  cache"; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return a.dev == b.dev ? a.ino - b.ino : a.dev - b.dev; } summary:nil],
		] retain];
		int i = 1;
		for (PSColumn *col in openfilesColumns) col.tag = i++;
		i = 1;
		for (PSColumn *col in modulesColumns) col.tag = i++;
	});
	return kind ? modulesColumns : openfilesColumns;
}

+ (NSArray *)psGetTaskColumnsWithWidth:(NSUInteger *)width kind:(NSInteger)kind
{
	NSArray *cols = [PSColumn psGetTaskColumns:kind];
	for (PSColumn *col in cols)
		*width -= col.width;
	*width += ((PSColumn *)cols[0]).width;
	return cols;
}

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width
	sortDesc:(BOOL)desc monoFont:(BOOL)mono data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary
{
	if (self = [super init]) {
		self.name = name;
		self.descr = descr;
		self.align = align;
		self.width = width;
		self.getData = data;
		self.getSummary = summary;
		self.sort = sort;
		self.sortDesc = desc;
		self.monoFont = mono;
	}
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width
	sortDesc:(BOOL)desc monoFont:(BOOL)mono data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary
{
	return [[[PSColumn alloc] initWithName:name descr:descr align:align width:width sortDesc:desc monoFont:mono data:data sort:sort summary:summary] autorelease];
}

- (void)dealloc
{
	[_name release];
	[_descr release];
	[super dealloc];
}

@end
