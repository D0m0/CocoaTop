#import <mach/mach_init.h>
#import <mach/mach_host.h>
#import <mach/host_info.h>
#import <pwd.h>
#import "ProcArray.h"
#import "NetArray.h"

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
		self.memUsed = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize;
		self.memFree = vm_stat.free_count * pagesize;
	}
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
	// Get buffer size
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
	size_t bufSize;
	if (sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0)
		return errno;
	// Make sure the buffer is large enough ;)
	bufSize *= 2;
	struct kinfo_proc *kp = (struct kinfo_proc *)malloc(bufSize);
	// Get process list and update the procs array
	int err = sysctl(mib, 4, kp, &bufSize, NULL, 0);
	if (!err) {
		for (int i = 0; i < bufSize / sizeof(struct kinfo_proc); i++) {
			PSProc *proc = [self procForPid:kp[i].kp_proc.p_pid];
			if (!proc) {
				proc = [PSProc psProcWithKinfo:&kp[i] iconSize:self.iconSize];
				[self.procs addObject:proc];
			} else {
				[proc updateWithKinfo:&kp[i]];
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
	}
	free(kp);
	[self refreshMemStats];
	[self.nstats refresh:self];
	return err;
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
	return [self.procs indexOfObjectPassingTest:^BOOL(PSProc *obj, NSUInteger idx, BOOL *stop) {
		return obj.display == display;
	}];
//	return [self.procs enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^void(PSProc *obj, NSUInteger idx, BOOL *stop) {
//		if (obj.display == display) *stop = YES;
//	}];
//	for (PSProc *proc in [self.procs reverseObjectEnumerator]) {
//		if (proc.display == display) return idx;
//	}
}

- (NSUInteger)count
{
	return self.procs.count;
}

- (PSProc *)objectAtIndexedSubscript:(NSUInteger)idx
{
	return (PSProc *)self.procs[idx];
}

- (NSUInteger)indexForPid:(pid_t)pid
{
	NSUInteger idx = [self.procs indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return ((PSProc *)obj).pid == pid;
	}];
	return idx;
}

- (PSProc *)procForPid:(pid_t)pid
{
	NSUInteger idx = [self indexForPid:pid];
	return idx == NSNotFound ? nil : (PSProc *)self.procs[idx];
}

@end
