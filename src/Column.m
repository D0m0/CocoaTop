#import "Compat.h"
#import "Column.h"
#import "Proc.h"
#import "ProcArray.h"
#import "Sock.h"
#import <pwd.h>
#import <grp.h>
#import <sys/stat.h>
#import <sys/fcntl.h>
#import <mach/mach_time.h>

NSString *psProcessStateString(PSProc *proc)
{
	static const char states[] = PROC_STATE_CHARS;
	unichar st[8], *pst = st;

	*pst++ = states[proc.state];
	if (proc.nice < 0)
		*pst++ = L'\u25B2';	// up
	else if (proc.nice > 0)
		*pst++ = L'\u25BC';	// down
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

@implementation PSColumn

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
		allColumns = @[
		[PSColumn psColumnWithName:@"Command line" fullname:@"Command line" align:NSTextAlignmentLeft width:170 tag:0 style:ColumnStylePathTrunc | ColumnStyleTooLong
			data:^NSString*(PSProc *proc) { return [proc.executable stringByAppendingString:proc.args]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"Total processes: %u", procs.count]; }
			descr:@"Full command line with path and arguments.\n\n"
				"If the name is given in brackets, then the command line cannot be acquired - usually it's either the Kernel or a zombie process.\n\n"
				"Summary of this column shows the total number of processes."],
		[PSColumn psColumnWithName:@"PID" fullname:@"Process ID" align:NSTextAlignmentRight width:50 tag:1 style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.pid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(pid); } summary:nil
			descr:@"Unique ID of a BSD process.\n\n"
				"This always grows upwards. Kernel is always pid 0, launchd is pid 1."],
		[PSColumn psColumnWithName:@"PPID" fullname:@"Parent PID" align:NSTextAlignmentRight width:50 tag:2 style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ppid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ppid); } summary:nil
			descr:@"Unique ID of process' parent - the one that called exec()/fork().\n\n"
				"On iOS most processes are jobs, thus they are launched by launchd and have parent pid 1."],
		[PSColumn psColumnWithName:@"%" fullname:@"%CPU Usage" align:NSTextAlignmentRight width:50 tag:3 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc.pcpu ? @"-" : [NSString stringWithFormat:@"%.1f", (float)proc.pcpu / 10]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(pcpu); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%.1f%%", (float)procs.totalCpu / 10]; }
			descr:@"The sum of CPU usage by all threads of a process.\n\n"
				"CPU usage is expressed in % per CPU core, thus it sums up to cores\u00D7100%. "
				"Sometimes it can even exceed this value, due to reasons explained in this app's 'About' section. This is hilarious!\n\n"
				"Summary of this column indicates total CPU usage."],
		[PSColumn psColumnWithName:@"Time" fullname:@"Process Time" align:NSTextAlignmentRight width:75 tag:4 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return psProcessCpuTime(proc.ptime); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ptime); }
			summary:^NSString*(PSProcArray* procs) { return psSystemUptime(); }
			descr:@"Total CPU time taken by the process - summed for all CPU cores.\n\n"
				"Summary of this column indicates OS uptime since kernel boot."],
		[PSColumn psColumnWithName:@"S" fullname:@"Mach Task State" align:NSTextAlignmentLeft width:30 tag:5 style:0
			data:^NSString*(PSProc *proc) { return psProcessStateString(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.state == b.state ? b->basic.suspend_count - a->basic.suspend_count : a.state - b.state; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%d/%d", procs.runningCount, procs.coresCount]; }
			descr:@"Process state (similar to original top).\n\nCan be one of the following:\n"
				"R	Running: at least one thread within this process is running now\n"
				"U	Uninterruptible (Stuck): a thread is waiting on I/O in a system call\n"
				"S	Sleeping: all threads of a process are sleeping\n"
				"I	Idle: all threads are sleeping for at least 20 seconds\n"
				"T	Terminated: all threads stopped\n"
				"H	Halted: all threads halted at a clean point\n"
				"D	The process is stopped by a signal (can be used for debugging)\n"
				"Z	Zombie: awaiting termination or 'orphan'\n"
				"?	Running state is unknown (access to threads was denied)\n\n"
				"Additional process attributes can follow:\n"
				"\u25BC	Nice: lower priority, also see 'Nice' column\n"
				"\u25B2	Not nice: higher priority\n"
				"t	Debugged process is being traced\n"
				"z	Process is being terminated at the moment\n"
				"w	Process' parent is waiting for this child after fork\n"
				"K	The system process (kernel)\n"
				"B	Application is suspended by SpringBoard (iOS specific)\n\n"
				"Summary of this column shows two numbers: the first one is the count of processes in running state, the second one is the number of CPU cores. "
				"Sometimes there are more running processes than there are CPU cores, but this is just a glitch due to kernel state changing while data is collected."],
		[PSColumn psColumnWithName:@"Flags" fullname:@"Raw Process Flags (Hex)" align:NSTextAlignmentLeft width:70 tag:6 style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%08X", proc.flags]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(flags); } summary:nil
			descr:@"Process flags represented as a hexadecimal number.\n\nThis is a bitmask composed of the following:\n"
				"0001	P_ADVLOCK		Process may hold POSIX adv. lock\n"
				"0002	P_CONTROLT    	Has a controlling terminal\n"
				"0004	P_LP64 			64-bit process\n"
				"0008	P_NOCLDSTOP 	Bad parent: no SIGCHLD when child stops\n"
				"0010	P_PPWAIT    	\tParent is waiting for this child to exec/exit\n"
				"0020	P_PROFIL    	\tHas started profiling\n"
				"0040	P_SELECT    	\tSelecting; wakeup/waiting danger\n"
				"0080	P_CONTINUED  	Process was stopped and continued\n"
				"0100	P_SUGID			Has set privileges since last exec\n"
				"0200	P_SYSTEM    	\tSystem process: no signals, stats or swap\n"
				"0400	P_TIMEOUT		Timing out during sleep\n"
				"0800	P_TRACED    	\tDebugged process being traced\n"
				"1000	P_DISABLE_ASLR	Disable address space randomization\n"
				"2000	P_WEXIT			Process is working on exiting\n"
				"4000	P_EXEC      	\tProcess has called exec()"],
				// "00040000 P_DELAYIDLESLEEP		Process is marked to delay idle sleep on disk IO\n"
				// "00080000 P_CHECKOPENEVT			Check if a vnode has the OPENEVT flag set on open\n"
				// "00100000 P_DEPENDENCY_CAPABLE	Process is ok to call vfs_markdependency()\n"
			//*	// "00200000 P_REBOOT				Process called reboot()\n"
				// "00400000 P_TBE					Process is TBE\n"
				// "00800000 P_SIGEXC*				Signal exceptions\n"
			//*	// "01000000 P_THCWD				Process has thread cwd\n"
			//*	// "02000000 P_VFORK*				Process has vfork children\n"
			//*	// "08000000 P_INVFORK				Process in vfork\n"
				// "10000000 P_NOSHLIB				no shared libs are in use for proc (flag set on exec)\n"
				// "20000000 P_FORCEQUOTA			Force quota for root\n"
			//*	// "40000000 P_NOCLDWAIT			No zombies when chil procs exit\n"
				// "80000000 P_NOREMOTEHANG			Don't hang on remote FS ops"],
		[PSColumn psColumnWithName:@"RMem" fullname:@"Resident Memory Usage" align:NSTextAlignmentRight width:70 tag:7 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->basic.resident_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.resident_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.resident_size); }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memUsed countStyle:NSByteCountFormatterCountStyleMemory]; }
			descr:@"Resident memory usage. Also see 'Physical Memory Footprint' column."],
		[PSColumn psColumnWithName:@"VSize" fullname:@"Virtual Address Space Usage" align:NSTextAlignmentRight width:70 tag:8 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->basic.virtual_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.virtual_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.virtual_size); }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memTotal countStyle:NSByteCountFormatterCountStyleMemory]; }
			descr:@"Virtual address space usage.\n\n"
				"This includes address space taken by dynamic libraries."],
		[PSColumn psColumnWithName:@"User" fullname:@"User Id" align:NSTextAlignmentLeft width:80 tag:9 style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:user_from_uid(proc.uid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(uid); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@" mobile: %d", procs.mobileCount]; }
			descr:@"Effective (current) user id.\n\n"
				"Summary of this column denotes the number of processes executing as user (aka 'mobile')."],
		[PSColumn psColumnWithName:@"Group" fullname:@"Group Id" align:NSTextAlignmentLeft width:80 tag:10 style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithCString:group_from_gid(proc.gid, 0) encoding:NSASCIIStringEncoding]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(gid); } summary:nil
			descr:@"Process group id."],
		[PSColumn psColumnWithName:@"TTY" fullname:@"Terminal" align:NSTextAlignmentLeft width:65 tag:11 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return psProcessTty(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(tdev); } summary:nil
			descr:@"For console processes this contains the name of the controlling terminal (TTY)"],
		[PSColumn psColumnWithName:@"Thr" fullname:@"Thread Count" align:NSTextAlignmentRight width:40 tag:12 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.threads]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(threads); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.threadCount]; }
			descr:@"Number of threads in the process.\n\n"
				"Tap the process and go to 'Threads' pane for lots of details."],
		[PSColumn psColumnWithName:@"Ports" fullname:@"Mach Ports" align:NSTextAlignmentRight width:50 tag:13 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ports]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ports); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.portCount]; }
			descr:@"Number of Mach ports opened by the process.\n\n"
				"Mach ports are the primary means of low-level communication with the kernel and between the processes in a microkernel environment."],
		[PSColumn psColumnWithName:@"Mach" fullname:@"Mach System Calls (Delta)" align:NSTextAlignmentRight width:52 tag:14 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,syscalls_mach)]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, syscalls_mach); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.machCalls]; }
			descr:@"Number of Mach system calls per update interval.\n\n"
				"Mach system calls are calls to the Mach microkernel within the XNU kernel. "
				"There are 180 to 200 Mach services available on iOS depending on kernel version."],
		[PSColumn psColumnWithName:@"BSD" fullname:@"BSD System Calls (Delta)" align:NSTextAlignmentRight width:52 tag:15 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,syscalls_unix)]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, syscalls_unix); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.unixCalls]; }
			descr:@"Number of BSD system calls per update interval.\n\n"
				"BSD system calls are calls to the BSD part of the XNU kernel. "
				"There are almost 1000 BSD services available on iOS depending on kernel version."],
		[PSColumn psColumnWithName:@"CSw" fullname:@"Context Switches (Delta)" align:NSTextAlignmentRight width:52 tag:16 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,csw)]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, csw); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.switchCount]; }
			descr:@"Number of context switches by this process per update interval.\n\n"
				"This is the number of times the CPU has activated this process to execute its code.\n\n"
				"Summary of this column indicates total number of context switches per update interval."],
		[PSColumn psColumnWithName:@"Prio" fullname:@"Mach Actual Threads Priority" align:NSTextAlignmentRight width:42 tag:17 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%@%u", 	proc->basic.policy == POLICY_RR ? @"R:" : proc->basic.policy == POLICY_FIFO ? @"F:" : @"", proc.prio]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(prio); } summary:nil
			descr:@"The highest priority of a thread within the process. Can be prefixed by the process' default scheduling scheme.\n\n"
				"There are several scheduling schemes supported by Mach, 'Time Sharing' being the default. The other two, 'Round-Robin' "
				"and 'FIFO', will be marked in this column using prefixes R: and F: respectively. Tap the process and go to 'Threads' pane to see "
				"actual priorities and scheduling schemes of every thread."],
		[PSColumn psColumnWithName:@"BPri" fullname:@"Base Process Priority" align:NSTextAlignmentRight width:42 tag:18 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.priobase]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(priobase); } summary:nil
			descr:@"The base thread priority of a process.\n\n"
				"This is the default priority set for newly created threads. Tap the process and go to "
				"'Threads' pane to see actual priorities and scheduling schemes of existing threads."],
		[PSColumn psColumnWithName:@"Nice" fullname:@"Process Nice Value" align:NSTextAlignmentRight width:42 tag:19 style:0
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%d", proc.nice]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(nice); } summary:nil
			descr:@"A positive 'nice' value lowers the priority of the process' threads. A negative value raises the priority.\n\n"
				"This is also indicated in the 'Process State' column by symbols \u25BC and \u25B2 respectively."],
		[PSColumn psColumnWithName:@"Role" fullname:@"Mach Task Role" align:NSTextAlignmentLeft width:75 tag:20 style:0
			data:^NSString*(PSProc *proc) { return psTaskRoleString(proc); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return (a.role + (a.role <= 0 ? 50 : 0)) - (b.role + (b.role <= 0 ? 50 : 0)); }
			summary:^NSString*(PSProcArray* procs) { return procs.guiCount ? [NSString stringWithFormat:@" UIApps: %d", procs.guiCount] : @"   -"; }
			descr:@"The assigned role for GUI apps (Mac-specific). This may not be shown on older iOS versions.\n\n"
				"Possible values are:\n"
				"None     	\tNon-UI task\n"
				"Foreground \tNormal UI application in the foreground\n"
				"Inactive 	\tNormal UI application in the background\n"
				"Background	OS X: Normal UI application in the background\n"
				"Controller	\tOS X: Controller service application\n"
				"GfxServer 	\tOS X: Graphics management (window) server\n"
				"Throttle 	\tOS X: Throttle application\n\n"
				"Summary of this column denotes the number of GUI processes (user applications)."],
		[PSColumn psColumnWithName:@"MSent" fullname:@"Mach Messages Sent" align:NSTextAlignmentRight width:70 tag:21 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_sent]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.messages_sent); } summary:nil
			descr:@"Total Mach messages sent by the process.\n\nMessages are sent using Mach ports. Also see 'Mach Ports' column."],
		[PSColumn psColumnWithName:@"MRecv" fullname:@"Mach Messages Received" align:NSTextAlignmentRight width:70 tag:22 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_received]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.messages_received); } summary:nil
			descr:@"Total Mach messages received by the process.\n\nMessages are received using Mach ports. Also see 'Mach Ports' column."],
		// Columns 23-29 have moved below (ios7 and up)
		[PSColumn psColumnWithName:@"\u03A3Mach" fullname:@"Mach Total System Calls" align:NSTextAlignmentRight width:52 tag:30 style:ColumnStyleForSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_mach]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.syscalls_mach); } summary:nil
			descr:@"Total number of Mach system calls by the process.\n\nAlso see 'Mach System Calls (Delta)' column."],
		[PSColumn psColumnWithName:@"\u03A3BSD" fullname:@"BSD Total System Calls" align:NSTextAlignmentRight width:52 tag:31 style:ColumnStyleForSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_unix]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.syscalls_unix); } summary:nil
			descr:@"Total number of BSD system calls by the process.\n\nAlso see 'BSD System Calls (Delta)' column."],
		[PSColumn psColumnWithName:@"\u03A3CSw" fullname:@"Context Switches Total" align:NSTextAlignmentRight width:52 tag:32 style:ColumnStyleForSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.csw]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.csw); } summary:nil
			descr:@"Total number of context switches by this process.\n\nAlso see 'Context Switches (Delta)' column."],
		[PSColumn psColumnWithName:@"FDs" fullname:@"Open file/socket Descriptors" align:NSTextAlignmentRight width:42 tag:33 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc.files ? @"-" : [NSString stringWithFormat:@"%u", proc.files]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(files); } summary:nil
			descr:@"Number of active file descriptors opened by process.\n\nThis includes open files, pipes, network sockets, kernel sockets, "
				"and kernel queues. Tap the process and go to 'Open Files' pane for lots of details."],
		[PSColumn psColumnWithName:@"" fullname:@"Bundle Identifier" align:NSTextAlignmentLeft width:0 tag:34 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleIdentifier"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" fullname:@"Bundle Name" align:NSTextAlignmentLeft width:0 tag:35 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleName"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" fullname:@"Bundle Display Name" align:NSTextAlignmentLeft width:0 tag:36 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleDisplayName"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" fullname:@"Bundle Version" align:NSTextAlignmentLeft width:0 tag:37 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"CFBundleVersion"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" fullname:@"Minimum OS Version" align:NSTextAlignmentLeft width:0 tag:38 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"MinimumOSVersion"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" fullname:@"Development SDK Version" align:NSTextAlignmentLeft width:0 tag:39 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"DTSDKName"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" fullname:@"Development Platform Version" align:NSTextAlignmentLeft width:0 tag:40 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"DTPlatformVersion"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"" fullname:@"Compiler Name" align:NSTextAlignmentLeft width:0 tag:41 style:ColumnStyleForSummary
			data:^NSString*(PSProc *proc) { return proc.app ? proc.app[@"DTCompiler"] : @"N/A"; } sort:nil summary:nil],
		[PSColumn psColumnWithName:@"NetRx" fullname:@"Net Bytes Received Delta" align:NSTextAlignmentRight width:70 tag:42 style:ColumnStyleNoSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !DELTA(proc,netstat,rxbytes) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,netstat,rxbytes) countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(netstat, rxbytes); } summary:nil
			descr:@"Network bytes received by process per update period."],
		[PSColumn psColumnWithName:@"NetTx" fullname:@"Net Bytes Sent Delta" align:NSTextAlignmentRight width:70 tag:43 style:ColumnStyleNoSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !DELTA(proc,netstat,txbytes) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,netstat,txbytes) countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(netstat, txbytes); } summary:nil
			descr:@"Network bytes transmitted by process per update period."],
		[PSColumn psColumnWithName:@"\u03A3NetRx" fullname:@"Net Total Bytes Received" align:NSTextAlignmentRight width:70 tag:44 style:ColumnStyleNoSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->netstat.rxbytes ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->netstat.rxbytes countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.rxbytes); } summary:nil
			descr:@"Network bytes received by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
		[PSColumn psColumnWithName:@"\u03A3NetTx" fullname:@"Net Total Bytes Sent" align:NSTextAlignmentRight width:70 tag:45 style:ColumnStyleNoSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->netstat.txbytes ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->netstat.txbytes countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.txbytes); } summary:nil
			descr:@"Network bytes transmitted by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
		[PSColumn psColumnWithName:@"\u03A3PktRx" fullname:@"Net Total Packets Received" align:NSTextAlignmentRight width:70 tag:46 style:ColumnStyleNoSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->netstat.rxpackets ? @"-" : [NSString stringWithFormat:@"%llu", proc->netstat.rxpackets]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.rxpackets); } summary:nil
			descr:@"Network packets received by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
		[PSColumn psColumnWithName:@"\u03A3PktTx" fullname:@"Net Total Packets Sent" align:NSTextAlignmentRight width:70 tag:47 style:ColumnStyleNoSummary | ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->netstat.txpackets ? @"-" : [NSString stringWithFormat:@"%llu", proc->netstat.txpackets]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.txpackets); } summary:nil
			descr:@"Network packets transmitted by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
		[PSColumn psColumnWithName:@"RMax" fullname:@"Maximum Resident Memory Usage" align:NSTextAlignmentRight width:70 tag:23 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->basic.resident_size_max ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.resident_size_max countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.resident_size_max); } summary:nil
			descr:@"Maximum resident memory usage since process launch."],
		[PSColumn psColumnWithName:@"Phys" fullname:@"Physical Memory Footprint" align:NSTextAlignmentRight width:70 tag:24 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->rusage.ri_phys_footprint ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->rusage.ri_phys_footprint countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_phys_footprint); } summary:nil
			descr:@"Physical memory footprint.\n\nThis is the most accurate RAM usage data by process."],
		[PSColumn psColumnWithName:@"DiskR" fullname:@"Disk I/O Bytes Read Delta" align:NSTextAlignmentRight width:70 tag:25 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !DELTA(proc,rusage,ri_diskio_bytesread) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,rusage,ri_diskio_bytesread) countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(rusage, ri_diskio_bytesread); } summary:nil
			descr:@"Bytes read from disk per update interval."],
		[PSColumn psColumnWithName:@"DiskW" fullname:@"Disk I/O Bytes Written Delta" align:NSTextAlignmentRight width:70 tag:26 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !DELTA(proc,rusage,ri_diskio_byteswritten) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,rusage,ri_diskio_byteswritten) countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(rusage, ri_diskio_byteswritten); } summary:nil
			descr:@"Bytes written to disk per update interval."],
		[PSColumn psColumnWithName:@"\u03A3DiskR" fullname:@"Disk I/O Total Bytes Read" align:NSTextAlignmentRight width:70 tag:27 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->rusage.ri_diskio_bytesread ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->rusage.ri_diskio_bytesread countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_diskio_bytesread); } summary:nil
			descr:@"Bytes read from disk since process launch."],
		[PSColumn psColumnWithName:@"\u03A3DiskW" fullname:@"Disk I/O Total Bytes Written" align:NSTextAlignmentRight width:70 tag:28 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return !proc->rusage.ri_diskio_byteswritten ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->rusage.ri_diskio_byteswritten countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_diskio_byteswritten); } summary:nil
			descr:@"Bytes written to disk since process launch."],
		[PSColumn psColumnWithName:@"\u03A3Time" fullname:@"Total Process Running Time" align:NSTextAlignmentRight width:75 tag:29 style:0
			data:^NSString*(PSProc *proc) { return psProcessUptime(proc->rusage.ri_proc_start_abstime, proc->rusage.ri_proc_exit_abstime); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(rusage.ri_proc_start_abstime); } summary:nil
			descr:@"Time elapsed since process launch."],
#endif
//		[PSColumn psColumnWithName:@"More" fullname:@"More Data" align:NSTextAlignmentLeft width:170 tag:9999 style:0
//			data:^NSString*(PSProc *proc) { return proc.moredata; }
//			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.moredata caseInsensitiveCompare:b.moredata]; } summary:nil],
		];
	});
	return allColumns;
}

+ (NSMutableArray *)psGetShownColumnsWithWidth:(NSUInteger)width
{
	NSArray *columnOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Columns"];
	NSMutableArray *shownCols = [NSMutableArray array];
	PSColumn *extendedcol = nil;
	// Sanity check
	if (columnOrder.count == 0)
		columnOrder = @[@0, @1, @3, @5, @7, @20];
	for (NSNumber* order in columnOrder) {
		PSColumn *col = [PSColumn psColumnWithTag:order.unsignedIntegerValue];
		if (!col) continue;
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
		sockColumns[ColumnModeSummary] = @[
		[PSColumn psColumnWithName:@"Column" fullname:@"Information Column" align:NSTextAlignmentLeft width:180 tag:1000 style:ColumnStyleEllipsis
			data:^NSString*(PSSockSummary *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"Value" fullname:@"Column Value" align:NSTextAlignmentLeft width:140 tag:1001 style:ColumnStyleExtend | ColumnStyleEllipsis
			data:^NSString*(PSSockSummary *sock) { return sock.col.getData(sock.proc); }
			sort:^NSComparisonResult(PSSock *a, PSSock *b) { return 0; } summary:nil],
		];
		sockColumns[ColumnModeThreads] = @[
		[PSColumn psColumnWithName:@"TID" fullname:@"Thread ID" align:NSTextAlignmentRight width:53 tag:2000 style:0
			data:^NSString*(PSSockThreads *sock) { return [NSString stringWithFormat:@"%llX", sock.tid]; }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE(tid); } summary:nil],
		[PSColumn psColumnWithName:@"%" fullname:@"%CPU Usage" align:NSTextAlignmentRight width:42 tag:2001 style:ColumnStyleSortDesc
			data:^NSString*(PSSockThreads *sock) { return !sock->tbi.cpu_usage ? @"-" : [NSString stringWithFormat:@"%.1f", (float)sock->tbi.cpu_usage / 10]; }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE_VAR(tbi.cpu_usage); } summary:nil],
		[PSColumn psColumnWithName:@"Time" fullname:@"Thread Time" align:NSTextAlignmentRight width:60 tag:2002 style:ColumnStyleSortDesc
			data:^NSString*(PSSockThreads *sock) { return psProcessCpuTime(sock.ptime); }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE(ptime); } summary:nil],
		[PSColumn psColumnWithName:@"S" fullname:@"Mach Thread State" align:NSTextAlignmentLeft width:33 tag:2003 style:0
			data:^NSString*(PSSockThreads *sock) { return psThreadStateString(sock); }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE_VAR(tbi.run_state); } summary:nil],
		[PSColumn psColumnWithName:@"Pri" fullname:@"Thread Priority" align:NSTextAlignmentRight width:37 tag:2004 style:ColumnStyleSortDesc
			data:^NSString*(PSSockThreads *sock) { return [NSString stringWithFormat:@"%@%u", sock->tbi.policy == POLICY_RR ? @"R:" : sock->tbi.policy == POLICY_FIFO ? @"F:" : @"", sock.prio]; }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { COMPARE(prio); } summary:nil],
		[PSColumn psColumnWithName:@"Name/Dispatch" fullname:@"Thread Name & Dispatch Queue" align:NSTextAlignmentLeft width:95 tag:2005 style:ColumnStyleExtend | ColumnStyleEllipsis
			data:^NSString*(PSSockThreads *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSockThreads *a, PSSockThreads *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		];
		sockColumns[ColumnModeFiles] = @[
		[PSColumn psColumnWithName:@"FD" fullname:@"File Descriptor" align:NSTextAlignmentRight width:40 tag:3000 style:0
			data:^NSString*(PSSockFiles *sock) { return [NSString stringWithFormat:@"%d", sock.fd]; }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { COMPARE(fd); } summary:nil],
		[PSColumn psColumnWithName:@"Open file/socket" fullname:@"Filename or Socket Address" align:NSTextAlignmentLeft width:220 tag:3001 style:ColumnStylePathTrunc
			data:^NSString*(PSSockFiles *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"Type" fullname:@"Descriptor Type" align:NSTextAlignmentLeft width:50 tag:3002 style:0
			data:^NSString*(PSSockFiles *sock) { return [NSString stringWithUTF8String:sock.stype]; }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { int res = strcmp(a.stype, b.stype); return COMPARE_ORDER(res, 0); } summary:nil],
		[PSColumn psColumnWithName:@"F" fullname:@"Open Flags" align:NSTextAlignmentLeft width:40 tag:3003 style:0
			data:^NSString*(PSSockFiles *sock) { return psFdFlagsString(sock.flags); }
			sort:^NSComparisonResult(PSSockFiles *a, PSSockFiles *b) { COMPARE(flags); } summary:nil],
		];
		sockColumns[ColumnModePorts] = @[
		[PSColumn psColumnWithName:@"Id" fullname:@"Port Name" align:NSTextAlignmentRight width:53 tag:5000 style:0
			data:^NSString*(PSSockPorts *sock) { return [NSString stringWithFormat:@"%X", sock.ind]; }
			sort:^NSComparisonResult(PSSockPorts *a, PSSockPorts *b) { COMPARE(ind); } summary:nil],
//		[PSColumn psColumnWithName:@"Refs" fullname:@"Reference Count" align:NSTextAlignmentRight width:37 tag:5001 style:ColumnStyleSortDesc
//			data:^NSString*(PSSockPorts *sock) { return [NSString stringWithFormat:@"%u", sock.refs]; }
//			sort:^NSComparisonResult(PSSockPorts *a, PSSockPorts *b) { COMPARE(refs); } summary:nil],
		[PSColumn psColumnWithName:@"Port Details" fullname:@"Port Details" align:NSTextAlignmentLeft width:220 tag:5002 style:ColumnStylePathTrunc
			data:^NSString*(PSSockPorts *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSockPorts *a, PSSockPorts *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		];
		sockColumns[ColumnModeModules] = @[
		[PSColumn psColumnWithName:@"Mapped module" fullname:@"Module Filename" align:NSTextAlignmentLeft width:220 tag:4000 style:ColumnStylePathTrunc
			data:^NSString*(PSSockModules *sock) { return sock.name; }
			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { return [a.name caseInsensitiveCompare:b.name]; } summary:nil],
		[PSColumn psColumnWithName:@"Addr" fullname:@"Loaded Virtual Address" align:NSTextAlignmentRight width:90 tag:4001 style:ColumnStyleMonoFont
			data:^NSString*(PSSockModules *sock) { return [NSString stringWithFormat:@"%llX", sock.addr]; }
			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { COMPARE(addr); } summary:nil],
//		[PSColumn psColumnWithName:@"End" fullname:@"End Virtual Address" align:NSTextAlignmentRight width:90 tag:4002 style:ColumnStyleMonoFont
//			data:^NSString*(PSSockModules *sock) { return sock.addrend == sock.addr ? @"-" : [NSString stringWithFormat:@"%llX", sock.addrend]; }
//			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { COMPARE(addrend); } summary:nil],
		[PSColumn psColumnWithName:@"iNode" fullname:@"Device and iNode of Module on Disk" align:NSTextAlignmentLeft width:80 tag:4003 style:0
			data:^NSString*(PSSockModules *sock) { return sock.dev && sock.ino ? [NSString stringWithFormat:@"%u,%u %u", sock.dev >> 24, sock.dev & ((1<<24)-1), sock.ino] : @"  cache"; }
			sort:^NSComparisonResult(PSSockModules *a, PSSockModules *b) { return a.dev == b.dev ? a.ino - b.ino : a.dev - b.dev; } summary:nil],
		];
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

+ (PSColumn *)psColumnWithTag:(NSInteger)tag
{
	NSArray *columns = [PSColumn psGetAllColumns];
	NSUInteger idx = [columns indexOfObjectPassingTest:^BOOL(PSColumn *col, NSUInteger idx, BOOL *stop) {
		return col.tag == tag;
	}];
	return idx == NSNotFound ? nil : (PSColumn *)columns[idx];
}

+ (PSColumn *)psTaskColumnWithTag:(NSInteger)tag forMode:(column_mode_t)mode
{
	NSArray *columns = [PSColumn psGetTaskColumns:mode];
	NSUInteger idx = [columns indexOfObjectPassingTest:^BOOL(PSColumn *col, NSUInteger idx, BOOL *stop) {
		return col.tag == tag;
	}];
	return idx == NSNotFound ? nil : (PSColumn *)columns[idx];
}

- (instancetype)initWithName:(NSString *)name fullname:(NSString *)fullname align:(NSTextAlignment)align width:(NSInteger)width
	tag:(NSInteger)tag style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary descr:(NSString *)descr
{
	if (self = [super init]) {
		self.name = name;
		self.fullname = fullname;
		self.descr = descr;
		self.align = align;
		self.minwidth = self.width = width;
		self.getData = data;
		self.getSummary = summary;
		self.sort = sort;
		self.tag = tag;
		self.style = style;
	}
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name fullname:(NSString *)fullname align:(NSTextAlignment)align width:(NSInteger)width
	tag:(NSInteger)tag style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary descr:(NSString *)descr
{
	return [[PSColumn alloc] initWithName:name fullname:fullname align:align width:width tag:tag style:style data:data sort:sort summary:summary descr:descr];
}

+ (instancetype)psColumnWithName:(NSString *)name fullname:(NSString *)fullname align:(NSTextAlignment)align width:(NSInteger)width
	tag:(NSInteger)tag style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary
{
	return [[PSColumn alloc] initWithName:name fullname:fullname align:align width:width tag:tag style:style data:data sort:sort summary:summary descr:nil];
}

@end
