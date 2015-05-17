#import <mach/mach_init.h>
#import <mach/mach_host.h>
#import <mach/host_info.h>
#import <pwd.h>
#import "ProcArray.h"

#import <sys/ioctl.h>
#import <sys/socket.h>
#import "sys/kern_control.h"
#import "sys/sys_domain.h"
#define PRIVATE
#import "net/ntstat.h"

int nstatAddSrc(int fd, int provider)
{
	nstat_msg_add_all_srcs aasreq;
	aasreq.provider = provider;
	aasreq.hdr.type = NSTAT_MSG_TYPE_ADD_ALL_SRCS;
	aasreq.hdr.context = 3;						// Some shit
	return write(fd, &aasreq, sizeof(aasreq));
}

int nstatQuerySrc(int fd, nstat_src_ref_t srcref)
{
	nstat_msg_query_src_req qsreq;
	qsreq.hdr.type = NSTAT_MSG_TYPE_QUERY_SRC;
	qsreq.srcref = srcref;
	qsreq.hdr.context = 1005;					// This way I can tell if errors get returned for dead sources
	return write(fd, &qsreq, sizeof(qsreq));
}

int nstatGetSrcDesc(int fd, nstat_provider_id_t provider, nstat_src_ref_t srcref)
{
	nstat_msg_get_src_description gsdreq;
	gsdreq.hdr.type = NSTAT_MSG_TYPE_GET_SRC_DESC;
	gsdreq.hdr.context = provider;
	gsdreq.srcref = srcref;
	return write(fd, &gsdreq, sizeof(gsdreq));
}

void NetStatCallBack(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
//	RootViewController *self = (RootViewController *)info;
	nstat_msg_hdr *ns = (nstat_msg_hdr *)CFDataGetBytePtr((CFDataRef)data);
	int len = CFDataGetLength((CFDataRef)data);

	if (!len)
		NSLog(@"NSTAT type:%lu, datasize:0", callbackType);
	else
	switch (ns->type) {
	case NSTAT_MSG_TYPE_SRC_ADDED:		NSLog(@"NSTAT_MSG_TYPE_SRC_ADDED, size:%d", len); /*nstatGetSrcDesc(int fd, int Prov, int Num);*/ break;
	case NSTAT_MSG_TYPE_SRC_REMOVED:	NSLog(@"NSTAT_MSG_TYPE_SRC_REMOVED, size:%d", len); break;
	case NSTAT_MSG_TYPE_SRC_DESC:		NSLog(@"NSTAT_MSG_TYPE_SRC_DESC, size:%d", len); break;
	case NSTAT_MSG_TYPE_SRC_COUNTS:		NSLog(@"NSTAT_MSG_TYPE_SRC_COUNTS, size:%d", len); break;
	case NSTAT_MSG_TYPE_SUCCESS:		NSLog(@"NSTAT_MSG_TYPE_SUCCESS, size:%d", len); break;
	case NSTAT_MSG_TYPE_ERROR:			NSLog(@"NSTAT_MSG_TYPE_ERROR, size:%d", len); break;
	default:							NSLog(@"NSTAT:%d, size:%d", ns->type, len); break;
	}
	// For each NSTAT_MSG_TYPE_SRC_ADDED:
	// NSTAT_MSG_TYPE_GET_SRC_DESC, srcref...
}

@implementation PSProcArray

- (instancetype)initProcArrayWithIconSize:(CGFloat)size
{
	self = [super init];
	if (!self) return nil;
	self.procs = [NSMutableArray arrayWithCapacity:200];
	self.iconSize = size;
	NSProcessInfo *procinfo = [NSProcessInfo processInfo];
	self.memTotal = procinfo.physicalMemory;
	self.coresCount = procinfo.processorCount;

	// Connect to netstat kernel extension
	CFSocketContext ctx = {0, self};
	self.netStat = CFSocketCreate(0, PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL, kCFSocketDataCallBack, NetStatCallBack, &ctx);
	CFRunLoopAddSource(
		[[NSRunLoop currentRunLoop] getCFRunLoop],
		CFSocketCreateRunLoopSource(0, self.netStat, 0/*order*/),
		kCFRunLoopCommonModes);
	struct ctl_info ctlInfo = {0, NET_STAT_CONTROL_NAME};
	int fd = CFSocketGetNative(self.netStat);
	if (ioctl(fd, CTLIOCGINFO, &ctlInfo) == -1) {
		NSLog(@"ioctl failed");
		CFSocketInvalidate(self.netStat);
		CFRelease(self.netStat);
		self.netStat = 0;
	} else {
		struct sockaddr_ctl sc = {sizeof(sc), AF_SYSTEM, AF_SYS_CONTROL, ctlInfo.ctl_id, 0};
		CFDataRef addr = CFDataCreate(0, (const UInt8 *)&sc, sizeof(sc));
		// Make a connect-callback, then do nstatAddSrc/nstatQuerySrc in the callback???
		CFSocketError err = CFSocketConnectToAddress(self.netStat, addr, .1);
		if (err != kCFSocketSuccess) {
			NSLog(@"CFSocketConnectToAddress err=%ld", err);
			CFSocketInvalidate(self.netStat);
			CFRelease(self.netStat);
			self.netStat = 0;
		} else {
			nstatAddSrc(fd, NSTAT_PROVIDER_TCP);
			nstatAddSrc(fd, NSTAT_PROVIDER_UDP);
			nstatQuerySrc(fd, NSTAT_SRC_REF_ALL);
		}
	}
	return self;
}

+ (instancetype)psProcArrayWithIconSize:(CGFloat)size
{
	return [[[PSProcArray alloc] initProcArrayWithIconSize:size] autorelease];
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
	return [self.procs indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return ((PSProc *)obj).display == display;
	}];
//	return [self.procs enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^void(id obj, NSUInteger idx, BOOL *stop) {
//		if (((PSProc *)obj).display == display) *stop = YES;
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

- (void)dealloc
{
	if (self.netStat) {
		CFSocketInvalidate(self.netStat);
		CFRelease(self.netStat);
		self.netStat = 0;
	}
	[_procs release];
	[super dealloc];
}

@end
