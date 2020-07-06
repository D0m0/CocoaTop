[PSColumn psColumnWithName:@"Command line" fullname:@"Command line" align:NSTextAlignmentLeft width:170 tag:0 style:ColumnStylePathTrunc | ColumnStyleTooLong
			data:^NSString*(PSProc *proc) { return [proc.executable stringByAppendingString:proc.args]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:procs.count == procs.totalCount ? @"Total processes: %lu" : @"Shown processes: %lu", (unsigned long)procs.count]; }
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
		[PSColumn psColumnWithName:@"%" fullname:@"%CPU Usage" align:NSTextAlignmentRight width:50 tag:3 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc.pcpu ? @"-" : [NSString stringWithFormat:@"%.1f", (float)proc.pcpu / 10]; }
			floatData:^double(PSProc *proc) { return (double)proc.pcpu / 10; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(pcpu); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%.1f%%", (float)procs.totalCpu / 10]; }
			color:^UIColor*(PSProc *proc) { DIFF(pcpu); }
			descr:@"The sum of CPU usage by all threads of a process.\n\n"
				"CPU usage is expressed in % per CPU core, thus it sums up to cores\u00D7100%. "
				"Sometimes it can even exceed this value, due to reasons explained in this app's 'About' section. This is hilarious!\n\n"
				"Summary of this column indicates total CPU usage."],
		[PSColumn psColumnWithName:@"Time" fullname:@"Process Time" align:NSTextAlignmentRight width:75 tag:4 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return psProcessCpuTime(proc.ptime); } floatData:^double(PSProc *proc) { return proc.ptime/100; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ptime); }
			summary:^NSString*(PSProcArray* procs) { return psSystemUptime(); }
			color:^UIColor*(PSProc *proc) { DIFF(ptime); }
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
		[PSColumn psColumnWithName:@"RMem" fullname:@"Resident Memory Usage" align:NSTextAlignmentRight width:70 tag:7 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc->basic.resident_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.resident_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			floatData:^double(PSProc *proc) { return proc->basic.resident_size; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.resident_size); }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memUsed countStyle:NSByteCountFormatterCountStyleMemory]; }
			color:^UIColor*(PSProc *proc) { DIFF_VAR(basic.resident_size); }
			descr:@"Resident memory usage. Also see 'Physical Memory Footprint' column."],
		[PSColumn psColumnWithName:@"VSize" fullname:@"Virtual Address Space Usage" align:NSTextAlignmentRight width:70 tag:8 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc->basic.virtual_size ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->basic.virtual_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			floatData:^double(PSProc *proc) { return proc->basic.virtual_size; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(basic.virtual_size); }
			summary:^NSString*(PSProcArray* procs) { return [NSByteCountFormatter stringFromByteCount:procs.memTotal countStyle:NSByteCountFormatterCountStyleMemory]; }
			color:^UIColor*(PSProc *proc) { DIFF_VAR(basic.virtual_size); }
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
			descr:@"For console processes this contains the name of the controlling terminal (TTY)."],
		[PSColumn psColumnWithName:@"Thr" fullname:@"Thread Count" align:NSTextAlignmentRight width:40 tag:12 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.threads]; } floatData:^double(PSProc *proc) { return proc.threads; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(threads); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.threadCount]; }
			color:^UIColor*(PSProc *proc) { DIFF(threads); }
			descr:@"Number of threads in the process.\n\n"
				"Tap the process and go to 'Threads' pane for lots of details."],
		[PSColumn psColumnWithName:@"Ports" fullname:@"Mach Ports" align:NSTextAlignmentRight width:50 tag:13 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ports]; } floatData:^double(PSProc *proc) { return proc.ports; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(ports); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.portCount]; }
			color:^UIColor*(PSProc *proc) { DIFF(ports); }
			descr:@"Number of Mach ports opened by the process.\n\n"
				"Mach ports are the primary means of low-level communication with the kernel and between the processes in a microkernel environment."],
		[PSColumn psColumnWithName:@"Mach" fullname:@"Mach System Calls (Delta)" align:NSTextAlignmentRight width:52 tag:14 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,syscalls_mach)]; }
			floatData:^double(PSProc *proc) { return DELTA(proc,events,syscalls_mach); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, syscalls_mach); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.machCalls]; }
			color:^UIColor*(PSProc *proc) { DIFF_DELTA(events, syscalls_mach); }
			descr:@"Number of Mach system calls per update interval.\n\n"
				"Mach system calls are calls to the Mach microkernel within the XNU kernel. "
				"There are 180 to 200 Mach services available on iOS depending on kernel version."],
		[PSColumn psColumnWithName:@"BSD" fullname:@"BSD System Calls (Delta)" align:NSTextAlignmentRight width:52 tag:15 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,syscalls_unix)]; }
			floatData:^double(PSProc *proc) { return DELTA(proc,events,syscalls_unix); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, syscalls_unix); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.unixCalls]; }
			color:^UIColor*(PSProc *proc) { DIFF_DELTA(events, syscalls_unix); }
			descr:@"Number of BSD system calls per update interval.\n\n"
				"BSD system calls are calls to the BSD part of the XNU kernel. "
				"There are almost 1000 BSD services available on iOS depending on kernel version."],
		[PSColumn psColumnWithName:@"CSw" fullname:@"Context Switches (Delta)" align:NSTextAlignmentRight width:52 tag:16 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", DELTA(proc,events,csw)]; }
			floatData:^double(PSProc *proc) { return DELTA(proc,events,csw); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(events, csw); }
			summary:^NSString*(PSProcArray* procs) { return [NSString stringWithFormat:@"%u", procs.switchCount]; }
			color:^UIColor*(PSProc *proc) { DIFF_DELTA(events, csw); }
			descr:@"Number of context switches by this process per update interval.\n\n"
				"This is the number of times the CPU has activated this process to execute its code.\n\n"
				"Summary of this column indicates total number of context switches per update interval."],
		[PSColumn psColumnWithName:@"Prio" fullname:@"Mach Actual Threads Priority" align:NSTextAlignmentRight width:42 tag:17 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%@%u", 	proc->basic.policy == POLICY_RR ? @"R:" : proc->basic.policy == POLICY_FIFO ? @"F:" : @"", proc.prio]; }
			floatData:^double(PSProc *proc) { return proc.prio; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(prio); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF(prio); }
			descr:@"The highest priority of a thread within the process. Can be prefixed by the process' default scheduling scheme.\n\n"
				"There are several scheduling schemes supported by Mach, 'Time Sharing' being the default. The other two, 'Round-Robin' "
				"and 'FIFO', will be marked in this column using prefixes R: and F: respectively. Tap the process and go to 'Threads' pane to see "
				"actual priorities and scheduling schemes of every thread."],
		[PSColumn psColumnWithName:@"BPri" fullname:@"Base Process Priority" align:NSTextAlignmentRight width:42 tag:18 style:ColumnStyleSortDesc
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.priobase]; } floatData:^double(PSProc *proc) { return proc.priobase; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(priobase); } summary:nil
			descr:@"The base thread priority of a process.\n\n"
				"This is the default priority set for newly created threads. Tap the process and go to "
				"'Threads' pane to see actual priorities and scheduling schemes of existing threads."],
		[PSColumn psColumnWithName:@"Nice" fullname:@"Process Nice Value" align:NSTextAlignmentRight width:42 tag:19 style:ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%d", proc.nice]; } floatData:^double(PSProc *proc) { return proc.nice; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(nice); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF(nice); }
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
		[PSColumn psColumnWithName:@"MSent" fullname:@"Mach Messages Sent" align:NSTextAlignmentRight width:70 tag:21 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_sent]; } floatData:^double(PSProc *proc) { return proc->events.messages_sent; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.messages_sent); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(events.messages_sent); }
			descr:@"Total Mach messages sent by the process.\n\nMessages are sent using Mach ports. Also see 'Mach Ports' column."],
		[PSColumn psColumnWithName:@"MRecv" fullname:@"Mach Messages Received" align:NSTextAlignmentRight width:70 tag:22 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.messages_received]; } floatData:^double(PSProc *proc) { return proc->events.messages_received; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.messages_received); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(events.messages_received); }
			descr:@"Total Mach messages received by the process.\n\nMessages are received using Mach ports. Also see 'Mach Ports' column."],
		// Columns 23-29 have moved below (ios7 and up)
		[PSColumn psColumnWithName:@"\u03A3Mach" fullname:@"Mach Total System Calls" align:NSTextAlignmentRight width:52 tag:30 style:ColumnStyleForSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_mach]; } floatData:^double(PSProc *proc) { return proc->events.syscalls_mach; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.syscalls_mach); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(events.syscalls_mach); }
			descr:@"Total number of Mach system calls by the process.\n\nAlso see 'Mach System Calls (Delta)' column."],
		[PSColumn psColumnWithName:@"\u03A3BSD" fullname:@"BSD Total System Calls" align:NSTextAlignmentRight width:52 tag:31 style:ColumnStyleForSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.syscalls_unix]; } floatData:^double(PSProc *proc) { return proc->events.syscalls_unix; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.syscalls_unix); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(events.syscalls_unix); }
			descr:@"Total number of BSD system calls by the process.\n\nAlso see 'BSD System Calls (Delta)' column."],
		[PSColumn psColumnWithName:@"\u03A3CSw" fullname:@"Context Switches Total" align:NSTextAlignmentRight width:52 tag:32 style:ColumnStyleForSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc->events.csw]; } floatData:^double(PSProc *proc) { return proc->events.csw; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(events.csw); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(events.csw); }
			descr:@"Total number of context switches by this process.\n\nAlso see 'Context Switches (Delta)' column."],
		[PSColumn psColumnWithName:@"FDs" fullname:@"Open File/Socket Descriptors" align:NSTextAlignmentRight width:42 tag:33 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc.files ? @"-" : [NSString stringWithFormat:@"%u", proc.files]; } floatData:^double(PSProc *proc) { return proc.files; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(files); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF(files); }
			descr:@"Number of active file descriptors opened by process.\n\nThis includes open files, pipes, network sockets, kernel sockets, "
				"and kernel queues. Tap the process and go to 'Open Files' pane for lots of details."],
		[PSColumn psColumnWithName:@"Sock" fullname:@"Open Socket Descriptors" align:NSTextAlignmentRight width:42 tag:48 style:ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc.socks ? @"-" : [NSString stringWithFormat:@"%u", proc.socks]; } floatData:^double(PSProc *proc) { return proc.socks; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE(socks); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF(socks); }
			descr:@"Number of active socket descriptors opened by process.\n\nThis includes IP network sockets, UNIX, and XNU kernel sockets. "
				"Tap the process and go to 'Open Files' pane for details."],
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
		[PSColumn psColumnWithName:@"NetRx" fullname:@"Net Bytes Received Delta" align:NSTextAlignmentRight width:70 tag:42 style:ColumnStyleNoSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !DELTA(proc,netstat,rxbytes) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,netstat,rxbytes) countStyle:NSByteCountFormatterCountStyleMemory]; }
			floatData:^double(PSProc *proc) { return DELTA(proc,netstat,rxbytes); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(netstat, rxbytes); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_DELTA(netstat, rxbytes); }
			descr:@"Network bytes received by process per update period."],
		[PSColumn psColumnWithName:@"NetTx" fullname:@"Net Bytes Sent Delta" align:NSTextAlignmentRight width:70 tag:43 style:ColumnStyleNoSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !DELTA(proc,netstat,txbytes) ? @"-" :
				[NSByteCountFormatter stringFromByteCount:DELTA(proc,netstat,txbytes) countStyle:NSByteCountFormatterCountStyleMemory]; }
			floatData:^double(PSProc *proc) { return DELTA(proc,netstat,txbytes); }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_DELTA(netstat, txbytes); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_DELTA(netstat, txbytes); }
			descr:@"Network bytes transmitted by process per update period."],
		[PSColumn psColumnWithName:@"\u03A3NetRx" fullname:@"Net Total Bytes Received" align:NSTextAlignmentRight width:70 tag:44 style:ColumnStyleNoSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc->netstat.rxbytes ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->netstat.rxbytes countStyle:NSByteCountFormatterCountStyleMemory]; }
			floatData:^double(PSProc *proc) { return proc->netstat.rxbytes; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.rxbytes); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(netstat.rxbytes); }
			descr:@"Network bytes received by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
		[PSColumn psColumnWithName:@"\u03A3NetTx" fullname:@"Net Total Bytes Sent" align:NSTextAlignmentRight width:70 tag:45 style:ColumnStyleNoSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc->netstat.txbytes ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->netstat.txbytes countStyle:NSByteCountFormatterCountStyleMemory]; }
			floatData:^double(PSProc *proc) { return proc->netstat.txbytes; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.txbytes); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(netstat.txbytes); }
			descr:@"Network bytes transmitted by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
		[PSColumn psColumnWithName:@"\u03A3PktRx" fullname:@"Net Total Packets Received" align:NSTextAlignmentRight width:70 tag:46 style:ColumnStyleNoSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc->netstat.rxpackets ? @"-" : [NSString stringWithFormat:@"%llu", proc->netstat.rxpackets]; }
			floatData:^double(PSProc *proc) { return proc->netstat.rxpackets; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.rxpackets); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(netstat.rxpackets); }
			descr:@"Network packets received by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
		[PSColumn psColumnWithName:@"\u03A3PktTx" fullname:@"Net Total Packets Sent" align:NSTextAlignmentRight width:70 tag:47 style:ColumnStyleNoSummary | ColumnStyleSortDesc | ColumnStyleColor
			data:^NSString*(PSProc *proc) { return !proc->netstat.txpackets ? @"-" : [NSString stringWithFormat:@"%llu", proc->netstat.txpackets]; }
			floatData:^double(PSProc *proc) { return proc->netstat.txpackets; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { COMPARE_VAR(netstat.txpackets); } summary:nil
			color:^UIColor*(PSProc *proc) { DIFF_VAR(netstat.txpackets); }
			descr:@"Network packets transmitted by process since launch.\n\n"
				"This value is inaccurate due to the fact that CocoaTop can only monitor process' sockets "
				"while it is active. Sockets having a lifetime during CocoaTop being inactive are not counted."],
