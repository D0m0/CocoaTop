#import "Column.h"
#import <pwd.h>
#import <grp.h>

@implementation PSColumn

NSString *psProcessStateString(PSProc *proc)
{
	static const char states[] = PSPROC_STATES;
	unichar st[16], *pst = st;

	*pst++ = states[proc.state];
	if (proc.exflags & PSPROC_EXFLAGS_NICE)			// 'v' p_nice > 0	U+02C5
		*pst++ = L'\u25BE';
	if (proc.exflags & PSPROC_EXFLAGS_NOTNICE)		// '^' p_nice < 0	U+02C4
		*pst++ = L'\u25B4';
	if (proc.exflags & PSPROC_EXFLAGS_TRACED)		// 't' P_TRACED (Debugged process being traced)
		*pst++ = 't';
	if (proc.exflags & PSPROC_EXFLAGS_WEXIT)		// 'z' P_WEXIT (Working on exiting)
		*pst++ = 'z';
	if (proc.exflags & PSPROC_EXFLAGS_PPWAIT)		// 'w' P_PPWAIT (Parent waiting for chld exec/exit)
		*pst++ = 'w';
	if (proc.exflags & PSPROC_EXFLAGS_SYSPROC)		// 'L' P_SYSTEM | P_NOSWAP | P_PHYSIO (Sys proc: no sigs, stats or swap)
		*pst++ = 'L';
	return [NSString stringWithCharacters:st length:(pst - st)];
}

NSString *psProcessTty(PSProc *proc)
{
	char *ttname = 0;
	if (proc.tdev != NODEV)
		ttname = devname(proc.tdev, S_IFCHR);
	return [NSString stringWithCString:(ttname ? ttname : "??") encoding:NSASCIIStringEncoding];
}

+ (NSArray *)psGetAllColumns
{
	static NSArray *allColumns;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		allColumns = [@[
		[PSColumn psColumnWithName:@"Command line" descr:@"Command line" align:NSTextAlignmentLeft width:600 refresh:NO
			data:^NSString*(PSProc *proc) { return proc.name; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }],
		[PSColumn psColumnWithName:@"PID" descr:@"Process ID" align:NSTextAlignmentRight width:50 refresh:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.pid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pid - b.pid; }],
		[PSColumn psColumnWithName:@"PPID" descr:@"Parent PID" align:NSTextAlignmentRight width:50 refresh:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ppid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ppid - b.ppid; }],
		[PSColumn psColumnWithName:@"Flags" descr:@"Raw Process Flags (Hex)" align:NSTextAlignmentLeft width:100 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%08X", proc.flags]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.flags - b.flags; }],
		[PSColumn psColumnWithName:@"Prio" descr:@"Mach Actual Threads Priority" align:NSTextAlignmentLeft width:42 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.prio]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.prio - b.prio; }],
		[PSColumn psColumnWithName:@"VSize" descr:@"Virtual Address Space Usage" align:NSTextAlignmentRight width:65 refresh:YES
			data:^NSString*(PSProc *proc) { return !proc->basic.virtual_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.virtual_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->basic.virtual_size - b->basic.virtual_size; }],
		[PSColumn psColumnWithName:@"RMem" descr:@"Resident Memory Usage" align:NSTextAlignmentRight width:65 refresh:YES
			data:^NSString*(PSProc *proc) { return !proc->basic.resident_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.resident_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->basic.resident_size - b->basic.resident_size; }],
		[PSColumn psColumnWithName:@"%" descr:@"%CPU Usage" align:NSTextAlignmentRight width:50 refresh:YES
			data:^NSString*(PSProc *proc) { return !proc.pcpu ? @"-" :
				[NSString stringWithFormat:@"%.1f", (float)proc.pcpu/10]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pcpu - b.pcpu; }],
		[PSColumn psColumnWithName:@"Thr" descr:@"Thread Count" align:NSTextAlignmentRight width:40 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.threads]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.threads - b.threads; }],
		[PSColumn psColumnWithName:@"BPri" descr:@"Base Process Priority" align:NSTextAlignmentLeft width:42 refresh:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.priobase]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.priobase - b.priobase; }],
		[PSColumn psColumnWithName:@"S" descr:@"Mach Task State" align:NSTextAlignmentLeft width:30 refresh:YES
			data:^NSString*(PSProc *proc) { return psProcessStateString(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.state - b.state; }],
		[PSColumn psColumnWithName:@"Nice" descr:@"Process Nice Value" align:NSTextAlignmentRight width:42 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.nice]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.nice - b.nice; }],
		[PSColumn psColumnWithName:@"Mach" descr:@"Mach system calls" align:NSTextAlignmentRight width:52 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_mach - proc->events_prev.syscalls_mach]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a->events.syscalls_mach - a->events_prev.syscalls_mach) - (b->events.syscalls_mach - b->events_prev.syscalls_mach); }],
		[PSColumn psColumnWithName:@"Unix" descr:@"Unix system calls" align:NSTextAlignmentRight width:52 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_unix - proc->events_prev.syscalls_unix]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a->events.syscalls_unix - a->events_prev.syscalls_unix) - (b->events.syscalls_unix - b->events_prev.syscalls_unix); }],
		[PSColumn psColumnWithName:@"CSw" descr:@"Context Switches" align:NSTextAlignmentRight width:52 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.csw - proc->events_prev.csw]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a->events.csw - a->events_prev.csw) - (b->events.csw - b->events_prev.csw); }],
		[PSColumn psColumnWithName:@"Time" descr:@"Process time" align:NSTextAlignmentRight width:75 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%lld:%02lld.%02lld", proc.ptime / 6000, (proc.ptime / 100) % 60, proc.ptime % 100]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ptime - b.ptime; }],
		[PSColumn psColumnWithName:@"TTY" descr:@"Terminal" align:NSTextAlignmentLeft width:65 refresh:NO
			data:^NSString*(PSProc *proc) { return psProcessTty(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.tdev - b.tdev; }],
		[PSColumn psColumnWithName:@"User" descr:@"User Id" align:NSTextAlignmentLeft width:90 refresh:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:user_from_uid(proc.uid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.uid - b.uid; }],
		[PSColumn psColumnWithName:@"Group" descr:@"Groud Id" align:NSTextAlignmentLeft width:90 refresh:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:group_from_gid(proc.gid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.gid - b.gid; }]
		// TIME Ports MRegions RPrivate RShared
		] retain];
	});
	return allColumns;
}

+ (NSMutableArray *)psGetShownColumns
{
	NSArray *columnOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Columns"];
	NSArray *cols = [PSColumn psGetAllColumns];
	NSMutableArray *shownCols = [NSMutableArray array];
	NSUInteger ccc = cols.count;

	for (NSNumber* order in columnOrder)
		if (order.unsignedIntegerValue < ccc)
			[shownCols addObject:cols[order.intValue]];
	return shownCols;
}

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width refresh:(BOOL)refresh data:(PSColumnData)data sort:(NSComparator)sort
{
	if (self = [super init]) {
		self.name = name;
		self.descr = descr;
		self.align = align;
		self.width = width;
		self.getData = data;
		self.sort = sort;
		self.refresh = refresh;
	}
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width refresh:(BOOL)refresh data:(PSColumnData)data sort:(NSComparator)sort
{
	return [[PSColumn alloc] initWithName:name descr:descr align:align width:width refresh:refresh data:data sort:sort];
}

/*
if (rawcpu) return p->p_pctcpu;

#define FSHIFT  11              // bits to right of fixed binary point
#define FSCALE  (1<<FSHIFT)
// decay 95% of `p_pctcpu' in 60 seconds; see CCPU_SHIFT before changing
fixpt_t ccpu = 0.95122942450071400909 * FSCALE;         // exp(-1/20)
return p->p_pctcpu / (1.0 - exp(p->p_swtime * log(fxtofl(ccpu))));

#define TH_USAGE_SCALE 1000
(void)printf("%*.1f", v->width, ((double)cp) * 100.0 / ((double)TH_USAGE_SCALE)); 
*/

- (void)dealloc
{
	[_name release];
	[_descr release];
	[super dealloc];
}

@end
