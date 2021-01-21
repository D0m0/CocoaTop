#import <mach/mach_init.h>
#import <mach/mach_host.h>
#import <mach/host_info.h>
#import <pwd.h>
#import "ProcArray.h"
#import "NetArray.h"

@implementation PSProcInfo
int sort_procs_by_pid(const void *p1, const void *p2)
{
	pid_t kp1 = ((struct kinfo_proc *)p1)->kp_proc.p_pid, kp2 = ((struct kinfo_proc *)p2)->kp_proc.p_pid;
	return kp1 == kp2 ? 0 : kp1 > kp2 ? 1 : -1;
}

- (instancetype)initProcInfoSort:(BOOL)sort
{
    static int maxproc;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        int mib[2];
        size_t len;

        mib[0] = CTL_KERN;
        mib[1] = KERN_MAXPROC;
        len = sizeof(maxproc);
        sysctl(mib, 2, &maxproc, &len, NULL,    0);
    });
    
	self = [super init];
	self->kp = 0;
	self->count = 0;
    
    // Get buffer size
    size_t alloc_size = maxproc * sizeof(struct kinfo_proc);
	size_t bufSize = 0;
    self->kp = (struct kinfo_proc *)malloc(alloc_size);
    static int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    if (self->kp == NULL) {
        if (sysctl(mib, 4, NULL, &alloc_size, NULL, 0) < 0)
            { self->ret = errno; return self; }
        alloc_size *= 2;
        self->kp = (struct kinfo_proc *)malloc(alloc_size);
    }
    bufSize = alloc_size;
	// Get process list
	self->ret = sysctl(mib, 4, self->kp, &bufSize, NULL, 0);
	if (self->ret)
		{ free(self->kp); self->kp = 0; return self; }
	self->count = bufSize / sizeof(struct kinfo_proc);
	if (sort)
		qsort(self->kp, self->count, sizeof(*kp), sort_procs_by_pid);
    if (@available(iOS 11, *)) {
    } else if (@available(iOS 10, *)) {
        if (self->kp[self->count - 1].kp_proc.p_pid == 1) {
            if (alloc_size > (self->count + 1) * sizeof(struct kinfo_proc)) {
                static int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, 0 };
                size_t length = sizeof(struct kinfo_proc);
                sysctl(mib, 4, &self->kp[self->count++], &length, NULL, 0);
            }
        }
    }
	return self;
}

+ (instancetype)psProcInfoSort:(BOOL)sort
{
	return [[PSProcInfo alloc] initProcInfoSort:sort];
}

- (void)dealloc
{
	if (self->kp) free(self->kp);
}
@end

@implementation PSProcArray

- (instancetype)initProcArrayWithIconSize:(CGFloat)size
{
	self = [super init];
	if (!self) return nil;
	self.iconSize = size;
	self.procs = [NSMutableArray arrayWithCapacity:300];
	self.nstats = [PSNetArray psNetArray];
	NSProcessInfo *procinfo = [NSProcessInfo processInfo];
	self.memTotal = procinfo.physicalMemory;
	self.coresCount = procinfo.processorCount;
	self.filterCount = 0;
	return self;
}

+ (instancetype)psProcArrayWithIconSize:(CGFloat)size
{
	return [[PSProcArray alloc] initProcArrayWithIconSize:size];
}

- (void)refreshMemStats
{
	mach_port_t host_port = mach_host_self();
	mach_msg_type_number_t host_size = HOST_VM_INFO64_COUNT;
	vm_statistics64_data_t vm_stat;
	vm_size_t pagesize;

	host_page_size(host_port, &pagesize);
	if (host_statistics64(host_port, HOST_VM_INFO64, (host_info_t)&vm_stat, &host_size) == KERN_SUCCESS) {
//		self.memUsed = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize;
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
//		self.memUsed += vm_stat.compressor_page_count * pagesize;
//#endif
		self.memFree = vm_stat.free_count * pagesize;
		self.memUsed = self.memTotal - self.memFree;
	}
/*
	host_cpu_load_info_data_t cpu_stat;
	host_size = HOST_CPU_LOAD_INFO_COUNT;
	if (host_statistics(host_port, HOST_CPU_LOAD_INFO, (host_info_t)&cpu_stat, &host_size) == KERN_SUCCESS) {
		cpu_stat.cpu_ticks[CPU_STATE_MAX]
	}
*/
}

- (int)refresh
{
	static uid_t mobileuid = 0;
	if (!mobileuid) {
		struct passwd *mobile = getpwnam("mobile");
		mobileuid = mobile->pw_uid;
	}
	// Reset totals
	self.totalCpu = self.threadCount = self.portCount = self.machCalls = self.unixCalls = self.switchCount = self.runningCount = self.mobileCount = self.guiCount = 0;
	// Remove terminated processes
	[self.procs filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(PSProc *obj, NSDictionary *bind) {
		return obj.display != ProcDisplayTerminated;
	}]];
	[self setAllDisplayed:ProcDisplayTerminated];
	// Get process list and update the procs array
	PSProcInfo *procs = [PSProcInfo psProcInfoSort:NO];
	if (procs->ret)
		return procs->ret;
	for (int i = 0; i < procs->count; i++) {
		PSProc *proc = [self procForPid:procs->kp[i].kp_proc.p_pid];
		if (!proc) {
			proc = [PSProc psProcWithKinfo:&procs->kp[i] iconSize:self.iconSize];
			[self.procs addObject:proc];
		} else {
			[proc updateWithKinfo:&procs->kp[i]];
			proc.display = ProcDisplayUser;
		}
		// Compute totals
		if (proc.pid) self.totalCpu += proc.pcpu;	// Kernel gets all idle CPU time
		if (proc.uid == mobileuid) self.mobileCount++;
		if (proc.state == ProcStateRunning) self.runningCount++;
		if (proc.role != TASK_UNSPECIFIED) self.guiCount++;
		self.threadCount += proc.threads;
		self.portCount += proc.ports;
		self.machCalls += proc->events.syscalls_mach - proc->events_prev.syscalls_mach;
		self.unixCalls += proc->events.syscalls_unix - proc->events_prev.syscalls_unix;
		self.switchCount += proc->events.csw - proc->events_prev.csw;
	}
	[self refreshMemStats];
	[self.nstats refresh:self];
	self.procsFiltered = self.procs;
	return 0;
}

- (void)sortUsingComparator:(NSComparator)comp desc:(BOOL)desc
{
	if (desc) {
		[self.procs sortUsingComparator:^NSComparisonResult(id a, id b) { return comp(b, a); }];
	} else
		[self.procs sortUsingComparator:comp];
}

- (void)setAllDisplayed:(display_t)display
{
	for (PSProc *proc in self.procs)
		// Setting all items to "normal" is used only to hide "started"
		if (display != ProcDisplayNormal || proc.display == ProcDisplayStarted)
			proc.display = display;
}

- (NSUInteger)indexOfDisplayed:(display_t)display
{
	return [self.procsFiltered indexOfObjectPassingTest:^BOOL(PSProc *proc, NSUInteger idx, BOOL *stop) {
		return proc.display == display;
	}];
//	return [self.procs enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^void(PSProc *proc, NSUInteger idx, BOOL *stop) {
//		if (proc.display == display) *stop = YES;
//	}];
//	for (PSProc *proc in [self.procs reverseObjectEnumerator]) {
//		if (proc.display == display) return idx;
//	}
}

- (NSUInteger)totalCount
{
	return self.procs.count;
}

- (NSUInteger)count
{
	return self.procsFiltered.count;
}

- (PSProc *)objectAtIndexedSubscript:(NSUInteger)idx
{
	return (PSProc *)self.procsFiltered[idx];
}

- (NSUInteger)indexForPid:(pid_t)pid
{
	NSUInteger idx = [self.procsFiltered indexOfObjectPassingTest:^BOOL(id proc, NSUInteger idx, BOOL *stop) {
		return ((PSProc *)proc).pid == pid;
	}];
	return idx;
}

- (PSProc *)procForPid:(pid_t)pid
{
	NSUInteger idx = [self.procs indexOfObjectPassingTest:^BOOL(id proc, NSUInteger idx, BOOL *stop) {
		return ((PSProc *)proc).pid == pid;
	}];
	return idx == NSNotFound ? nil : (PSProc *)self.procs[idx];
}

- (void)filter:(NSString *)text column:(PSColumn *)col
{
	if (text && text.length) {
		self.procsFiltered = [self.procs mutableCopy];
		if (col.getFloatData != nil) {
			double minValue = [text doubleValue];
			switch([text characterAtIndex:text.length-1]) {
			case 'k': case 'K': minValue *= 1024; break;
			case 'm': case 'M': minValue *= 1024*1024; break;
			case 'g': case 'G': minValue *= 1024*1024*1024; break;
			}
			[self.procsFiltered filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(PSProc *proc, NSDictionary *bind) {
				return col.getFloatData(proc) >= minValue;
			}]];
		} else
			[self.procsFiltered filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(PSProc *proc, NSDictionary *bind) {
				return [col.getData(proc) rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound;
			}]];
	} else
		self.procsFiltered = self.procs;
}

@end
