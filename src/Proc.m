#import <mach/mach_host.h>
#import <mach/task_info.h>
#import <mach/thread_info.h>
#import <mach/mach_interface.h>
#import <mach/mach_port.h>
#import "Compat.h"
#import "Proc.h"
#import "AppIcon.h"
#import "sys/proc_info.h"
#import "sys/libproc.h"

@implementation PSProc

- (instancetype)initWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size
{
	if (self = [super init]) {
		@autoreleasepool {
			self.display = ProcDisplayStarted;
			self.pid = ki->kp_proc.p_pid;
			self.ppid = ki->kp_eproc.e_ppid;
			self.dispQueue = [NSMutableDictionary new];
//			self.cpuhistory = [NSMutableArray new];
//			for (int i = 0; i < 50; i++)
//				[self.cpuhistory insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:0];
			NSArray *args = [PSProc getArgsByKinfo:ki];
			char buffer[MAXPATHLEN];
			if (proc_pidpath(self.pid, buffer, sizeof(buffer)))
				self.executable = [NSString stringWithUTF8String:buffer];
			else
				self.executable = args[0];
			self.args = @"";
			for (int i = 1; i < args.count; i++)
				self.args = [self.args stringByAppendingFormat:@" %@", args[i]];
			NSString *path = [self.executable stringByDeletingLastPathComponent];
			self.app = [PSAppIcon getAppByPath:path];
			memset(&events, 0, sizeof(events));
			memset(&netstat, 0, sizeof(netstat));
			memset(&netstat_cache, 0, sizeof(netstat_cache));
			memset(&rusage, 0, sizeof(rusage));
			NSString *firslCol = [[NSUserDefaults standardUserDefaults] stringForKey:@"FirstColumnStyle"];
			if (self.app) {
				NSString *ident = self.app[@"CFBundleIdentifier"];
				if (ident)
					self.icon = [PSAppIcon getIconForApp:self.app bundle:ident path:path size:size];
				if ([firslCol isEqualToString:@"Bundle Identifier"])
					self.name = ident;
				else if ([firslCol isEqualToString:@"Bundle Name"])
					self.name = self.app[@"CFBundleName"];
				else if ([firslCol isEqualToString:@"Bundle Display Name"])
					self.name = self.app[@"CFBundleDisplayName"];
			}
			if ([firslCol isEqualToString:@"Executable With Args"])
				self.name = [[self.executable lastPathComponent] stringByAppendingString:self.args];
			if (!self.name || [firslCol isEqualToString:@"Executable Name"])
				self.name = [self.executable lastPathComponent];
			self.executable = [PSSymLink simplifyPathName:self.executable];
			[self updateWithKinfo:ki];
		}
	}
	return self;
}

+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size
{
	return [[PSProc alloc] initWithKinfo:ki iconSize:size];
}

- (instancetype)psProcCopy
{
	PSProc *proc = [PSProc new];
	proc.prio = self.prio;
	proc.nice = self.nice;
	proc.ptime = self.ptime;
	proc.pcpu = self.pcpu;
	proc.threads = self.threads;
	proc.ports = self.ports;
	proc.files = self.files;
	proc.socks = self.socks;
	memcpy(&proc->basic, &basic, sizeof(basic));
	memcpy(&proc->events, &events, sizeof(events));
	memcpy(&proc->rusage, &rusage, sizeof(rusage));
	memcpy(&proc->netstat, &netstat, sizeof(netstat));
	memcpy(&proc->events_prev, &events_prev, sizeof(events_prev));
	memcpy(&proc->rusage_prev, &rusage_prev, sizeof(rusage_prev));
	memcpy(&proc->netstat_prev, &netstat_prev, sizeof(netstat_prev));
	return proc;
}

// Thread states are sorted by priority, top priority becomes a "task state"
proc_state_t mach_state_order(struct thread_basic_info *tbi)
{
	switch (tbi->run_state) {
	case TH_STATE_RUNNING:			return ProcStateRunning;
	case TH_STATE_UNINTERRUPTIBLE:	return ProcStateUninterruptible;
	case TH_STATE_WAITING:			return tbi->sleep_time <= 20 ? ProcStateSleeping : ProcStateIndefiniteSleep;
	case TH_STATE_STOPPED:			return ProcStateTerminated;
	case TH_STATE_HALTED:			return ProcStateHalted;  
	default:						return ProcStateMax; 
	}
}

unsigned int mach_thread_priority(thread_t thread, policy_t policy)
{
	// this struct is compatible with all scheduler policies
	struct policy_timeshare_info sched;
	unsigned int info_count;
	switch (policy) {
	case POLICY_TIMESHARE:
		info_count = POLICY_TIMESHARE_INFO_COUNT;
		if (thread_info(thread, THREAD_SCHED_TIMESHARE_INFO, (thread_info_t)&sched, &info_count) == KERN_SUCCESS)
			return sched.cur_priority;
		break;
	case POLICY_RR:
		info_count = POLICY_RR_INFO_COUNT;
		if (thread_info(thread, THREAD_SCHED_RR_INFO, (thread_info_t)&sched, &info_count) == KERN_SUCCESS)
			return sched.base_priority;
		break;
	case POLICY_FIFO:
		info_count = POLICY_FIFO_INFO_COUNT;
		if (thread_info(thread, THREAD_SCHED_FIFO_INFO, (thread_info_t)&sched, &info_count) == KERN_SUCCESS)
			return sched.base_priority;
		break;
	}
	return 0;
}

- (void)updateWithKinfo:(struct kinfo_proc *)ki
{
	self.priobase = ki->kp_proc.p_priority;
	self.flags = ki->kp_proc.p_flag;
	self.nice = ki->kp_proc.p_nice;
	self.tdev = ki->kp_eproc.e_tdev;
	self.uid = ki->kp_eproc.e_ucred.cr_uid;
	self.gid = ki->kp_eproc.e_pcred.p_rgid;
	// Priority process states
	self.state = ProcStateMax;
	if (ki->kp_proc.p_stat == SSTOP) self.state = ProcStateDebugging;
	if (ki->kp_proc.p_stat == SZOMB) self.state = ProcStateZombie;
//	self.moredata = [NSString stringWithFormat:@"%x %x %x", ki->kp_proc.p_xstat, ki->kp_proc.p_acflag, ki->kp_proc.sigwait];
	[self update];
}

- (void)update
{
	// Mach task info
	[self updateMachInfo];
	// Open files count
	self.files = self.socks = 0;
	int bufSize = proc_pidinfo(self.pid, PROC_PIDLISTFDS, 0, 0, 0);
	if (bufSize > 0) {
		bufSize *= 2;
		struct proc_fdinfo *fdinfo = (struct proc_fdinfo *)malloc(bufSize);
		if (fdinfo) {
			bufSize = proc_pidinfo(self.pid, PROC_PIDLISTFDS, 0, fdinfo, bufSize);
			if (bufSize > 0)
				for (int i = 0; i < bufSize / PROC_PIDLISTFD_SIZE; i++) {
					switch (fdinfo[i].proc_fdtype) {
					case PROX_FDTYPE_SOCKET:
						self.socks++;
					case PROX_FDTYPE_VNODE:
					case PROX_FDTYPE_PIPE:
					case PROX_FDTYPE_KQUEUE:
						self.files++; break;
					}
				}
			free(fdinfo);
		}
	}
	// NetStat info
	memcpy(&netstat_prev, &netstat, sizeof(netstat));
	memcpy(&netstat, &netstat_cache, sizeof(netstat));
	// Rusage info (iOS7+)
	memcpy(&rusage_prev, &rusage, sizeof(rusage));
	memset(&rusage, 0, sizeof(rusage));
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (@available(iOS 7, *)) {
        if (proc_pid_rusage(self.pid, RUSAGE_INFO_V2, &rusage) == 0) {
            if (!rusage_prev.ri_proc_start_abstime)
                // Fill in rusage_prev on first update
                memcpy(&rusage_prev, &rusage, sizeof(rusage_prev));
            // Values for kernel (pid 0) can only be acquired from rusage on iOS7+
            if (!basic.resident_size)
                basic.resident_size = rusage.ri_resident_size;
            if (!self.ptime)
                self.ptime = mach_time_to_milliseconds(rusage.ri_user_time + rusage.ri_system_time) / 10;	// 100's of a second
        }
    }
//#endif
}

- (void)updateMachInfo
{
	time_value_t total_time = {0};
	task_port_t task;

	self.prev = [self psProcCopy];
	// Task info
	memcpy(&events_prev, &events, sizeof(events_prev));
	memset(&basic, 0, sizeof(basic));
	self.threads = 0;
	self.prio = 0;
	self.pcpu = 0;
	self.ptime = 0;

    extern kern_return_t _task_for_pid(pid_t pid, task_port_t *target);
    if (_task_for_pid(self.pid, &task) != KERN_SUCCESS)
		return;
	// Basic task info
	unsigned int info_count = MACH_TASK_BASIC_INFO_COUNT;
	if (task_info(task, MACH_TASK_BASIC_INFO, (task_info_t)&basic, &info_count) == KERN_SUCCESS) {
		// Time
		total_time = basic.user_time;
		time_value_add(&total_time, &basic.system_time);
		// Task scheduler info
		struct policy_rr_base sched = {0};			// this struct is compatible with all task scheduling policies
		switch (basic.policy) {
		case POLICY_TIMESHARE:
			info_count = POLICY_TIMESHARE_INFO_COUNT;
			if (task_info(task, TASK_SCHED_TIMESHARE_INFO, (task_info_t)&sched, &info_count) == KERN_SUCCESS)
				self.priobase = sched.base_priority;
			break;
		case POLICY_RR:
			info_count = POLICY_RR_INFO_COUNT;
			if (task_info(task, TASK_SCHED_RR_INFO, (task_info_t)&sched, &info_count) == KERN_SUCCESS)
				self.priobase = sched.base_priority;
			break;
		case POLICY_FIFO:
			info_count = POLICY_FIFO_INFO_COUNT;
			if (task_info(task, TASK_SCHED_FIFO_INFO, (task_info_t)&sched, &info_count) == KERN_SUCCESS)
				self.priobase = sched.base_priority;
			break;
		}
	}
	// Task policy
	task_category_policy_data_t policy_info = {TASK_UNSPECIFIED};
	boolean_t get_default = NO;
	info_count = TASK_CATEGORY_POLICY_COUNT;
	task_policy_get(task, TASK_CATEGORY_POLICY, (task_policy_t)&policy_info, &info_count, &get_default);
	self.role = policy_info.role;
    if (@available(iOS 11, *)) {
    } else if (@available(iOS 10, *)) {
        if (self.pid == 0)
            goto task_port;
    }
	// Task times
	struct task_thread_times_info times;
	info_count = TASK_THREAD_TIMES_INFO_COUNT;
	if (task_info(task, TASK_THREAD_TIMES_INFO, (task_info_t)&times, &info_count) != KERN_SUCCESS)
		memset(&times, 0, sizeof(times));
	time_value_add(&total_time, &times.user_time);
	time_value_add(&total_time, &times.system_time);
	// Task events
	info_count = TASK_EVENTS_INFO_COUNT;
	if (task_info(task, TASK_EVENTS_INFO, (task_info_t)&events, &info_count) != KERN_SUCCESS)
		memset(&events, 0, sizeof(events));
	else if (!events_prev.csw)	// Fill in events_prev on first update
		memcpy(&events_prev, &events, sizeof(events_prev));
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (@available(iOS 7, *)) {
        // Task power info
        // uint64_t total_user, total_system;
        info_count = TASK_POWER_INFO_COUNT;
        if (task_info(task, TASK_POWER_INFO, (task_info_t)&power, &info_count) != KERN_SUCCESS)
            memset(&power, 0, sizeof(power));
        else if (!power_prev.total_user)	// Fill in power_prev on first update
            memcpy(&power_prev, &power, sizeof(power_prev));
        power.task_timer_wakeups_bin_1 += power.task_timer_wakeups_bin_2;
    }
//#endif
    task_port:;
	// Task ports
	mach_msg_type_number_t ncnt, tcnt;
	mach_port_name_array_t names;
	mach_port_type_array_t types;
	if (mach_port_names(task, &names, &ncnt, &types, &tcnt) == KERN_SUCCESS) {
		vm_deallocate(mach_task_self(), (vm_address_t)names, ncnt * sizeof(*names));
		vm_deallocate(mach_task_self(), (vm_address_t)types, tcnt * sizeof(*types));
		self.ports = ncnt;
	} else
		self.ports = 0;
	// Enumerate all threads to acquire detailed info
	thread_port_array_t thread_list;
	unsigned int thread_count;
	if (task_threads(task, &thread_list, &thread_count) == KERN_SUCCESS) {
		self.threads = thread_count;
		for (unsigned int j = 0; j < thread_count; j++) {
			struct thread_basic_info tbi;
			info_count = THREAD_BASIC_INFO_COUNT;
			if (thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)&tbi, &info_count) == KERN_SUCCESS) {
				if (!(tbi.flags & TH_FLAGS_IDLE))
					self.pcpu += tbi.cpu_usage;
				unsigned int prio = mach_thread_priority(thread_list[j], tbi.policy);
				// Actual process priority will be the largest priority of a thread
				if (self.prio < prio) self.prio = prio;
			}
			// Task state is formed from all thread states
			proc_state_t thstate = mach_state_order(&tbi);
			if (self.state > thstate)
				self.state = thstate;
			mach_port_deallocate(mach_task_self(), thread_list[j]);
		}
		// Deallocate the list of threads
		vm_deallocate(mach_task_self(), (vm_address_t)thread_list, sizeof(*thread_list) * thread_count);
	}
	mach_port_deallocate(mach_task_self(), task);
	// Roundup time: 100's of a second
	self.ptime = total_time.seconds * 100 + (total_time.microseconds + 5000) / 10000;
//	[self.cpuhistory insertObject:[NSNumber numberWithUnsignedInt:self.pcpu] atIndex:0];
//	if (self.cpuhistory.count > 50) [self.cpuhistory removeLastObject];
}

+ (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki
{
	NSArray		*args = nil;
	int			nargs, c = 0;
	static int	argmax = 0;
	char		*argsbuf, *sp, *cp;
	int			mib[3] = {CTL_KERN, KERN_PROCARGS2, ki->kp_proc.p_pid};
	size_t		size;

	if (!argmax) {
		int mib2[2] = {CTL_KERN, KERN_ARGMAX};
		size = sizeof(argmax);
		if (sysctl(mib2, 2, &argmax, &size, NULL, 0) < 0)
			argmax = 1024;
	}
	// Allocate process environment buffer
	argsbuf = (char *)malloc(argmax);
	if (argsbuf) {
		size = (size_t)argmax;
		if (sysctl(mib, 3, argsbuf, &size, NULL, 0) == 0) {
			// Skip args count
			nargs = *(int *)argsbuf;
			cp = argsbuf + sizeof(nargs);
			// Skip exec_path and trailing nulls
			for (; cp < &argsbuf[size]; cp++)
				if (!*cp) break;
			for (; cp < &argsbuf[size]; cp++)
				if (*cp) break;
			for (sp = cp; cp < &argsbuf[size] && c < nargs; cp++)
				if (*cp == '\0') c++;
			while (sp < cp && sp[0] == '/' && sp[1] == '/') sp++;
			if (sp != cp) {
				args = [[[NSString alloc] initWithBytes:sp length:(cp-sp) encoding:NSUTF8StringEncoding]
					componentsSeparatedByString:@"\0"];
			}
		}
		free(argsbuf);
	}
	if (args)
		return args;
	ki->kp_proc.p_comm[MAXCOMLEN] = 0;	// Just in case
	return [NSArray arrayWithObject:[NSString stringWithFormat:@"(%s)", ki->kp_proc.p_comm]];
}

@end
