#import "Column.h"
#import "Proc.h"
#import "Sock.h"
#import <pwd.h>
#import <grp.h>
#import <sys/stat.h>
#import <sys/fcntl.h>
#import <mach/mach_time.h>

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

NSString *psThreadStateString(PSSockThreads *sock)
{
	static const char states[] = PROC_STATE_CHARS;
	unichar st[8], *pst = st;

	*pst++ = states[mach_state_order(&sock->tbi)];
	if (sock->tbi.flags & TH_FLAGS_SWAPPED)
		*pst++ = L's';
	if (sock->tbi.flags & TH_FLAGS_IDLE)
		*pst++ = L'i';
	if (sock->tbi.suspend_count)
		*pst++ = L'B';
	return [NSString stringWithCharacters:st length:(pst - st)];
}

NSString *psFdFlagsString(uint32_t openflags)
{
	unichar st[8], *pst = st;

	if (openflags & FREAD)
		*pst++ = L'R';
	if (openflags & FWRITE)
		*pst++ = L'W';
	if (openflags & O_APPEND)
		*pst++ = L'A';
	if (openflags & O_EXLOCK)
		*pst++ = L'L';
	if (openflags & O_NONBLOCK)
		*pst++ = L'N';
	if (openflags & O_EVTONLY)
		*pst++ = L'E';
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
	static struct timeval boottime = {0};
	if (boottime.tv_sec == 0) {
		int mib[2] = {CTL_KERN, KERN_BOOTTIME};
		size_t size = sizeof(boottime);
	    sysctl(mib, 2, &boottime, &size, NULL, 0);
	}
    if (boottime.tv_sec) {
		time_t uptime;
		time(&uptime);
		uptime -= boottime.tv_sec;
		time_t days = uptime/60/60/24;
		return days ? [NSString stringWithFormat:@"%ldd %02ld:%02ld:%02ld", days, (uptime/60/60) % 24, (uptime/60) % 60, uptime % 60]
					: [NSString stringWithFormat:@"%ld:%02ld:%02ld", uptime/60/60, (uptime/60) % 60, uptime % 60];
	} else
		return @"-";
}

NSString *psProcessUptime(uint64_t uptime, uint64_t exittime)
{
	if (!uptime)
		return @"-";
	if (!exittime) exittime = mach_absolute_time();
	uptime = mach_time_to_milliseconds(exittime - uptime) / 1000;
	uint64_t days = uptime/60/60/24;
	return days ? [NSString stringWithFormat:@"%llud %02llu:%02llu:%02llu", days, (uptime/60/60) % 24, (uptime/60) % 60, uptime % 60]
				: [NSString stringWithFormat:@"%llu:%02llu:%02llu", uptime/60/60, (uptime/60) % 60, uptime % 60];
}

NSString *psProcessCpuTime(unsigned int ptime)
{
	unsigned int hours = ptime/100/60/60;
	return hours ? [NSString stringWithFormat:@"%u:%02u:%02u.%02u", hours, (ptime / 6000) % 60, (ptime / 100) % 60, ptime % 100]
				 : [NSString stringWithFormat:@"%u:%02u.%02u", ptime / 6000, (ptime / 100) % 60, ptime % 100];
}

#define DELTA(ptr, field1, field2) ((ptr)->field1.field2 - (ptr)->field1 ## _prev.field2)
#define COMPARE_ORDER(a, b) ((a) == (b) ? NSOrderedSame : (a) > (b) ? NSOrderedDescending : NSOrderedAscending)
#define COMPARE(field) return COMPARE_ORDER(a.field, b.field);
#define COMPARE_VAR(field) return COMPARE_ORDER(a->field, b->field);
#define COMPARE_DELTA(field1, field2) return COMPARE_ORDER(DELTA(a,field1,field2), DELTA(b,field1,field2));

+ (NSArray *)psGetAllColumns
{
	static NSArray *allColumns;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		allColumns = [@[
		[PSColumn psColumnWithName:@"Command line" descr:@"Command line" align:NSTextAlignmentLeft width:170 sortDesc:NO style:ColumnStyleExtend | ColumnStyleEllipsis | ColumnStyleTooLong
			data:^NSString*(PSProc *proc) { return [proc.executable stringByAppendingString:proc.args]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"Total processes: %u", procs.count]; }],
		[PSColumn psColumnWithName:@"PID" descr:@"Process ID" align:NSTextAlignmentRight width:50 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.pid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(pid); } summary:nil],
		[PSColumn psColumnWithName:@"PPID" descr:@"Parent PID" align:NSTextAlignmentRight width:50 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ppid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ppid); } summary:nil],
		[PSColumn psColumnWithName:@"%" descr:@"%CPU Usage" align:NSTextAlignmentRight width:50 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc.pcpu ? @"-" : [NSString stringWithFormat:@"%.1f", (float)proc.pcpu / 10]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(pcpu); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%.1f%%", (float)procs.totalCpu / 10]; }],
		[PSColumn psColumnWithName:@"Time" descr:@"Process Time" align:NSTextAlignmentRight width:75 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return psProcessCpuTime(proc.ptime); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ptime); }
			summary:^NSString*(PSProcArray* procs) { return psSystemUptime(); }],
		[PSColumn psColumnWithName:@"S" descr:@"Mach Task State" align:NSTextAlignmentLeft width:30 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return psProcessStateString(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.state == b.state ? b->basic.suspend_count - a->basic.suspend_count : a.state - b.state; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%d/%d", procs.runningCount, procs.coresCount]; }],
		[PSColumn psColumnWithName:@"Flags" descr:@"Raw Process Flags (Hex)" align:NSTextAlignmentLeft width:70 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%08X", proc.flags]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(flags); } summary:nil],
		[PSColumn psColumnWithName:@"RMem" descr:@"Resident Memory Usage" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc->basic.resident_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.resident_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.resident_size); }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memUsed countStyle:NSByteCountFormatterCountStyleMemory]; }],
		[PSColumn psColumnWithName:@"VSize" descr:@"Virtual Address Space Usage" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc->basic.virtual_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.virtual_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.virtual_size); }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memTotal countStyle:NSByteCountFormatterCountStyleMemory]; }],
		[PSColumn psColumnWithName:@"User" descr:@"User Id" align:NSTextAlignmentLeft width:80 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:user_from_uid(proc.uid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(uid); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@" mobile: %d", procs.mobileCount]; }],
		[PSColumn psColumnWithName:@"Group" descr:@"Group Id" align:NSTextAlignmentLeft width:80 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:group_from_gid(proc.gid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(gid); } summary:nil],
		[PSColumn psColumnWithName:@"TTY" descr:@"Terminal" align:NSTextAlignmentLeft width:65 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return psProcessTty(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(tdev); } summary:nil],
		[PSColumn psColumnWithName:@"Thr" descr:@"Thread Count" align:NSTextAlignmentRight width:40 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.threads]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(threads); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.threadCount]; }],
		[PSColumn psColumnWithName:@"Ports" descr:@"Mach Ports" align:NSTextAlignmentRight width:50 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ports]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ports); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.portCount]; }],
		[PSColumn psColumnWithName:@"Mach" descr:@"Mach System Calls (Delta)" align:NSTextAlignmentRight width:52 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,syscalls_mach)]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, syscalls_mach); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.machCalls]; }],
		[PSColumn psColumnWithName:@"BSD" descr:@"BSD System Calls (Delta)" align:NSTextAlignmentRight width:52 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,syscalls_unix)]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, syscalls_unix); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.unixCalls]; }],
		[PSColumn psColumnWithName:@"CSw" descr:@"Context Switches (Delta)" align:NSTextAlignmentRight width:52 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,csw)]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, csw); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.switchCount]; }],
		[PSColumn psColumnWithName:@"Prio" descr:@"Mach Actual Threads Priority" align:NSTextAlignmentRight width:42 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%@%u", 	proc->basic.policy == POLICY_RR ? @"R:" : proc->basic.policy == POLICY_FIFO ? @"F:" : @"", proc.prio]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(prio); } summary:nil],
		[PSColumn psColumnWithName:@"BPri" descr:@"Base Process Priority" align:NSTextAlignmentRight width:42 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.priobase]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(priobase); } summary:nil],
		[PSColumn psColumnWithName:@"Nice" descr:@"Process Nice Value" align:NSTextAlignmentRight width:42 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%d", proc.nice]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(nice); } summary:nil],
		[PSColumn psColumnWithName:@"Role" descr:@"Mach Task Role" align:NSTextAlignmentLeft width:75 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return psTaskRoleString(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a.role + (a.role <= 0 ? 50 : 0)) - (b.role + (b.role <= 0 ? 50 : 0)); }
			summary:^NSString*(PSProcArray* procs) { return procs.guiCount ? [NSString stringWithFormat:@" UIApps: %d", procs.guiCount] : @"   -"; }],
		[PSColumn psColumnWithName:@"MSent" descr:@"Mach Messages Sent" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_sent]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.messages_sent); } summary:nil],
		[PSColumn psColumnWithName:@"MRecv" descr:@"Mach Messages Received" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_received]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.messages_received); } summary:nil],
		[PSColumn psColumnWithName:@"\u03A3Mach" descr:@"Mach Total System Calls" align:NSTextAlignmentRight width:52 sortDesc:YES style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_mach]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.syscalls_mach); } summary:nil],
		[PSColumn psColumnWithName:@"\u03A3BSD" descr:@"BSD Total System Calls" align:NSTextAlignmentRight width:52 sortDesc:YES style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_unix]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.syscalls_unix); } summary:nil],
		[PSColumn psColumnWithName:@"\u03A3CSw" descr:@"Context Switches Total" align:NSTextAlignmentRight width:52 sortDesc:YES style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.csw]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.csw); } summary:nil],
		[PSColumn psColumnWithName:@"FDs" descr:@"Open file/socket Descriptors" align:NSTextAlignmentRight width:42 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc.files ? @"-" : [NSString stringWithFormat:@"%u", proc.files]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(files); } summary:nil],
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
		[PSColumn psColumnWithName:@"RMax" descr:@"Maximum Resident Memory Usage" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc->basic.resident_size_max ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.resident_size_max countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.resident_size_max); } summary:nil],
		[PSColumn psColumnWithName:@"Phys" descr:@"Physical Memory Footprint" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc->rusage.ri_phys_footprint ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->rusage.ri_phys_footprint countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_phys_footprint); } summary:nil],
		[PSColumn psColumnWithName:@"DiskR" descr:@"Disk I/O Bytes Read Delta" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !DELTA(proc,rusage,ri_diskio_bytesread) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,rusage,ri_diskio_bytesread) countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(rusage, ri_diskio_bytesread); } summary:nil],
		[PSColumn psColumnWithName:@"DiskW" descr:@"Disk I/O Bytes Written Delta" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !DELTA(proc,rusage,ri_diskio_byteswritten) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,rusage,ri_diskio_byteswritten) countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(rusage, ri_diskio_byteswritten); } summary:nil],
		[PSColumn psColumnWithName:@"\u03A3DiskR" descr:@"Disk I/O Total Bytes Read" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc->rusage.ri_diskio_bytesread ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->rusage.ri_diskio_bytesread countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_diskio_bytesread); } summary:nil],
		[PSColumn psColumnWithName:@"\u03A3DiskW" descr:@"Disk I/O Total Bytes Written" align:NSTextAlignmentRight width:70 sortDesc:YES style:0
			data:^NSString*(PSProc *proc) { return !proc->rusage.ri_diskio_byteswritten ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->rusage.ri_diskio_byteswritten countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_diskio_byteswritten); } summary:nil],
		[PSColumn psColumnWithName:@"\u03A3Time" descr:@"Total Process Running Time" align:NSTextAlignmentRight width:75 sortDesc:NO style:0
			data:^NSString*(PSProc *proc) { return psProcessUptime(proc->rusage.ri_proc_start_abstime, proc->rusage.ri_proc_exit_abstime); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_proc_start_abstime); } summary:nil],
#endif
		[PSColumn psColumnWithName:@"" descr:@"Bundle Identifier" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleIdentifier"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" descr:@"Bundle Name" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleName"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" descr:@"Bundle Display Name" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleDisplayName"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" descr:@"Bundle Version" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleVersion"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" descr:@"Minimum OS Version" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"MinimumOSVersion"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" descr:@"Development SDK Version" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"DTSDKName"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" descr:@"Development Platform Version" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"DTPlatformVersion"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" descr:@"Compiler Name" align:NSTextAlignmentLeft width:0 sortDesc:NO style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"DTCompiler"] : @"N/A"; } sort:nil summary:nil],
		] retain];
		int i = 1; for (PSColumn *col in allColumns) col.tag = i++;
	});
	return allColumns;
}

+ (NSMutableArray *)psGetShownColumnsWithWidth:(NSUInteger)width
{
	NSArray *columnOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Columns"];
	NSArray *cols = [PSColumn psGetAllColumns];
	NSMutableArray *shownCols = [NSMutableArray array];
	PSColumn *extendedcol = nil;
	// Sanity check
	if (columnOrder.count == 0)
		columnOrder = @[@0, @1, @2, @3, @6, @7, @8];
	for (NSNumber* order in columnOrder)
		if (order.unsignedIntegerValue < cols.count) {
			PSColumn *col = cols[order.unsignedIntegerValue];
			if (width < col.minwidth) break;
			[shownCols addObject:col];
			col.width = col.minwidth;
			width -= col.width;
			if (col.style & ColumnStyleExtend)
				extendedcol = col;
		}
	if (extendedcol)
		extendedcol.width = extendedcol.minwidth + width;
	return shownCols;
}

+ (NSArray *)psGetTaskColumns:(column_mode_t)mode
{
	static NSArray *sockColumns[ColumnModes];
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sockColumns[ColumnModeSummary] = [@[
		[PSColumn psColumnWithName:@"Column" descr:@"Information Column" align:NSTextAlignmentLeft width:180 sortDesc:NO style:ColumnStyleEllipsis
			data:^NSString*(PSSockSummary *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"Value" descr:@"Column Value" align:NSTextAlignmentLeft width:140 sortDesc:NO style:ColumnStyleExtend | ColumnStyleEllipsis
			data:^NSString*(PSSockSummary *sock) { return sock.col.getData(sock.proc); }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return 0; } summary:nil],
		] retain];
		sockColumns[ColumnModeThreads] = [@[
		[PSColumn psColumnWithName:@"TID" descr:@"Thread ID" align:NSTextAlignmentRight width:100 sortDesc:NO style:0
			data:^NSString*(PSSockThreads *sock) { return [NSString stringWithFormat:@"%llX", sock.tid]; }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE(tid); } summary:nil],
		[PSColumn psColumnWithName:@"%" descr:@"%CPU Usage" align:NSTextAlignmentRight width:50 sortDesc:YES style:0
			data:^NSString*(PSSockThreads *sock) { return !sock->tbi.cpu_usage ? @"-" : [NSString stringWithFormat:@"%.1f", (float)sock->tbi.cpu_usage / 10]; }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE_VAR(tbi.cpu_usage); } summary:nil],
		[PSColumn psColumnWithName:@"Time" descr:@"Thread Time" align:NSTextAlignmentRight width:75 sortDesc:YES style:0
			data:^NSString*(PSSockThreads *sock) { return psProcessCpuTime(sock.ptime); }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE(ptime); } summary:nil],
		[PSColumn psColumnWithName:@"S" descr:@"Mach Thread State" align:NSTextAlignmentLeft width:33 sortDesc:NO style:0
			data:^NSString*(PSSockThreads *sock) { return psThreadStateString(sock); }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE_VAR(tbi.run_state); } summary:nil],
		[PSColumn psColumnWithName:@"Prio" descr:@"Thread Priority" align:NSTextAlignmentRight width:42 sortDesc:YES style:0
			data:^NSString*(PSSockThreads *sock) { return [NSString stringWithFormat:@"%@%u", sock->tbi.policy == POLICY_RR ? @"R:" : sock->tbi.policy == POLICY_FIFO ? @"F:" : @"", sock.prio]; }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE(prio); } summary:nil],
		] retain];
		sockColumns[ColumnModeFiles] = [@[
		[PSColumn psColumnWithName:@"FD" descr:@"File Descriptor" align:NSTextAlignmentRight width:40 sortDesc:NO style:0
			data:^NSString*(PSSockFiles *sock) { return [NSString stringWithFormat:@"%d", sock.fd]; }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { COMPARE(fd); } summary:nil],
		[PSColumn psColumnWithName:@"Open file/socket" descr:@"Filename or Socket Address" align:NSTextAlignmentLeft width:220 sortDesc:NO style:ColumnStyleExtend | ColumnStyleEllipsis
			data:^NSString*(PSSockFiles *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"Type" descr:@"Descriptor Type" align:NSTextAlignmentLeft width:50 sortDesc:NO style:0
			data:^NSString*(PSSockFiles *sock) { return [NSString stringWithUTF8String:sock.stype]; }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { COMPARE(type); } summary:nil],
		[PSColumn psColumnWithName:@"F" descr:@"Open Flags" align:NSTextAlignmentLeft width:40 sortDesc:NO style:0
			data:^NSString*(PSSockFiles *sock) { return psFdFlagsString(sock.flags); }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { COMPARE(flags); } summary:nil],
		] retain];
		sockColumns[ColumnModeModules] = [@[
		[PSColumn psColumnWithName:@"Mapped module" descr:@"Module Filename" align:NSTextAlignmentLeft width:220 sortDesc:NO style:ColumnStyleExtend | ColumnStyleEllipsis
			data:^NSString*(PSSockModules *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"Addr" descr:@"Loaded Virtual Address" align:NSTextAlignmentRight width:90 sortDesc:NO style:ColumnStyleMonoFont
			data:^NSString*(PSSockModules *sock) { return [NSString stringWithFormat:@"%llX", sock.addr]; }
			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { COMPARE(addr); } summary:nil],
//		[PSColumn psColumnWithName:@"End" descr:@"End Virtual Address" align:NSTextAlignmentRight width:90 sortDesc:NO style:ColumnStyleMonoFont
//			data:^NSString*(PSSockModules *sock) { return sock.addrend == sock.addr ? @"-" : [NSString stringWithFormat:@"%llX", sock.addrend]; }
//			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { return a.addrend == b.addrend ? 0 : a.addrend > b.addrend ? 1 : -1; } summary:nil],
		[PSColumn psColumnWithName:@"iNode" descr:@"Device and iNode of Module on Disk" align:NSTextAlignmentLeft width:80 sortDesc:NO style:0
			data:^NSString*(PSSockModules *sock) { return sock.dev && sock.ino ? [NSString stringWithFormat:@"%u,%u %u", sock.dev >> 24, sock.dev & ((1<<24)-1), sock.ino] : @"  cache"; }
			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { return a.dev == b.dev ? a.ino - b.ino : a.dev - b.dev; } summary:nil],
		] retain];
		int i, j = 1; for (i = 0; i < ColumnModes; i++, j = 1) for (PSColumn *col in sockColumns[i]) col.tag = j++;
	});
	return sockColumns[mode];
}

+ (NSArray *)psGetTaskColumnsWithWidth:(NSUInteger)width mode:(column_mode_t)mode
{
	NSArray *cols = [PSColumn psGetTaskColumns:mode];
	PSColumn *extendedcol = nil;
	for (PSColumn *col in cols) {
		col.width = col.minwidth;
		width -= col.width;
		if (col.style & ColumnStyleExtend)
			extendedcol = col;
	}
	if (extendedcol)
		extendedcol.width = extendedcol.minwidth + width;
	return cols;
}

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width
	sortDesc:(BOOL)desc style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary
{
	if (self = [super init]) {
		self.name = name;
		self.descr = descr;
		self.align = align;
		self.minwidth = self.width = width;
		self.getData = data;
		self.getSummary = summary;
		self.sort = sort;
		self.sortDesc = desc;
		self.style = style;
	}
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width
	sortDesc:(BOOL)desc style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary
{
	return [[[PSColumn alloc] initWithName:name descr:descr align:align width:width sortDesc:desc style:style data:data sort:sort summary:summary] autorelease];
}

- (void)dealloc
{
	[_name release];
	[_descr release];
	[super dealloc];
}

@end
