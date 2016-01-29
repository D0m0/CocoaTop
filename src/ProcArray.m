#import <mach/mach_init.h>
#import <mach/mach_host.h>
#import <mach/host_info.h>
#import <pwd.h>
#import "ProcArray.h"

#import <sys/utsname.h>
#import <sys/ioctl.h>
#import <sys/socket.h>
#import "sys/kern_control.h"
#import "sys/sys_domain.h"
#define PRIVATE
#import "net/ntstat.h"

@interface NSValue(PSCounts)
+ (instancetype)valueWithCounts:(PSCounts)value;
@property (readonly) PSCounts countsValue;
@end

@implementation NSValue(PSCounts)
+ (instancetype)valueWithCounts:(PSCounts)value
{
	return [self valueWithBytes:&value objCType:@encode(PSCounts)];
}
- (PSCounts)countsValue
{
	PSCounts value;
	[self getValue:&value];
	return value;
}
@end

int nstatAddSrc(int fd, int provider, u_int64_t ctx)
{
	nstat_msg_add_all_srcs aasreq = {{ctx, NSTAT_MSG_TYPE_ADD_ALL_SRCS, 0}, provider, NSTAT_FILTER_ACCEPT_ALL | NSTAT_FILTER_PROVIDER_NOZEROBYTES | NSTAT_FILTER_REQUIRE_SRC_ADDED};
	return write(fd, &aasreq, sizeof(aasreq));
}

int nstatQuerySrc(int fd, nstat_src_ref_t srcref, u_int64_t ctx)
{
	nstat_msg_query_src_req qsreq = {{ctx, NSTAT_MSG_TYPE_QUERY_SRC, 0}, srcref};
	return write(fd, &qsreq, sizeof(qsreq));
}

int nstatGetSrcDesc(int fd, nstat_provider_id_t provider, nstat_src_ref_t srcref)
{
	nstat_msg_get_src_description gsdreq = {{provider, NSTAT_MSG_TYPE_GET_SRC_DESC, 0}, srcref};
	return write(fd, &gsdreq, sizeof(gsdreq));
}

void NetStatCallBack(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
	PSProcArray *self = (PSProcArray *)info;
	int fd = CFSocketGetNative(s);
	nstat_msg_hdr *ns = (nstat_msg_hdr *)CFDataGetBytePtr((CFDataRef)data);
	int len = CFDataGetLength((CFDataRef)data);

	if (!len || callbackType != kCFSocketDataCallBack) {
		// 100% working hack: if an empty packet comes in, we should just reconnect
		NSLog(@"NSTAT: callbackType=%lu len=%d, reconnecting...", callbackType, len);
		[self openNetStat];
		return;
	}
	switch (ns->type) {
	case NSTAT_MSG_TYPE_SRC_ADDED: {
		nstat_msg_src_added *nsa = (nstat_msg_src_added *)ns;
		nstatGetSrcDesc(fd, nsa->provider, nsa->srcref);
		break; }
	case NSTAT_MSG_TYPE_SRC_REMOVED: {
		nstat_msg_src_removed *nsr = (nstat_msg_src_removed *)ns;
		NSValue *srcval = self.nstats[@(nsr->srcref)];
		if (srcval) {
			PSCounts cnt = srcval.countsValue;
			PSProc *proc = [self procForPid:cnt.pid];
			if (proc) {
				proc->netstat_cache.rxpackets += cnt.rxpackets; proc->netstat_cache.rxbytes += cnt.rxbytes;
				proc->netstat_cache.txpackets += cnt.txpackets; proc->netstat_cache.txbytes += cnt.txbytes;
			}
			[self.nstats removeObjectForKey:@(nsr->srcref)];
		}
		break; }
	case NSTAT_MSG_TYPE_SRC_DESC: {
		nstat_msg_src_description *nmsd = (nstat_msg_src_description *)ns;
		PSCounts cnt = {-1, nmsd->provider, nmsd->srcref, 0, 0, 0, 0};
		NSValue *srcval = self.nstats[@(nmsd->srcref)];
		if (srcval)
			cnt = srcval.countsValue;
		if (nmsd->provider == NSTAT_PROVIDER_UDP) {
			if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0)
				cnt.pid = ((nstat_udp_descriptor_ios6_9 *)nmsd->data)->epid;
			else if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_6_0)
				cnt.pid = ((nstat_udp_descriptor_ios6_9 *)nmsd->data)->pid;
			else
				cnt.pid = ((nstat_udp_descriptor_ios5 *)nmsd->data)->pid;
		} else if (nmsd->provider == NSTAT_PROVIDER_TCP) {
			if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_8_0)
				cnt.pid = ((nstat_tcp_descriptor_ios8_9 *)nmsd->data)->epid;
			else if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0)
				cnt.pid = ((nstat_tcp_descriptor_ios6_7 *)nmsd->data)->epid;
			else if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_6_0)
				cnt.pid = ((nstat_tcp_descriptor_ios6_7 *)nmsd->data)->pid;
			else
				cnt.pid = ((nstat_tcp_descriptor_ios5 *)nmsd->data)->pid;
		}
		if (cnt.pid > 0) {
			self.nstats[@(nmsd->srcref)] = [NSValue valueWithCounts:cnt];
			nstatQuerySrc(fd, nmsd->srcref, nmsd->srcref);
		}
		break; }
	case NSTAT_MSG_TYPE_SRC_COUNTS: {
		nstat_msg_src_counts *cnts = (nstat_msg_src_counts *)ns;
		NSValue *srcval = self.nstats[@(cnts->srcref)];
		if (srcval) {
			PSCounts cnt = srcval.countsValue;
			cnt.rxpackets = cnts->counts.nstat_rxpackets; cnt.rxbytes = cnts->counts.nstat_rxbytes;
			cnt.txpackets = cnts->counts.nstat_txpackets; cnt.txbytes = cnts->counts.nstat_txbytes;
			self.nstats[@(cnts->srcref)] = [NSValue valueWithCounts:cnt];
		}
		break; }
//	case NSTAT_MSG_TYPE_SUCCESS:	NSLog(@"NSTAT_MSG_TYPE_SUCCESS, size:%d, ctx:%llu", len, ns->context); break;
//	case NSTAT_MSG_TYPE_ERROR:		NSLog(@"NSTAT_MSG_TYPE_ERROR, size:%d, ctx:%llu", len, ns->context); break;
//	default:						NSLog(@"NSTAT:%d, size:%d, ctx:%llu", ns->type, len, ns->context);
	}
}

@implementation PSProcArray

- (void)openNetStat
{
	[self closeNetStat];
	CFSocketContext ctx = {0, self};
	self.netStat = CFSocketCreate(0, PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL, kCFSocketDataCallBack, NetStatCallBack, &ctx);
	CFRunLoopAddSource(
		[[NSRunLoop currentRunLoop] getCFRunLoop],
		CFSocketCreateRunLoopSource(0, self.netStat, 0/*order*/),
		kCFRunLoopCommonModes);
	int fd = CFSocketGetNative(self.netStat);
	if (!self.netStatAddr) {
		struct ctl_info ctlInfo = {0, NET_STAT_CONTROL_NAME};
		if (ioctl(fd, CTLIOCGINFO, &ctlInfo) == -1) {
			NSLog(@"NSTAT ioctl failed");
			[self closeNetStat];
			return;
		}
		struct sockaddr_ctl sc = {sizeof(sc), AF_SYSTEM, AF_SYS_CONTROL, ctlInfo.ctl_id, 0};
		self.netStatAddr = CFDataCreate(0, (const UInt8 *)&sc, sizeof(sc));
	}
	// Make a connect-callback, then do nstatAddSrc/nstatQuerySrc in the callback???
	CFSocketError err = CFSocketConnectToAddress(self.netStat, self.netStatAddr, .1);
	if (err != kCFSocketSuccess) {
		NSLog(@"NSTAT CFSocketConnectToAddress err=%ld", err);
		[self closeNetStat];
		return;
	}
	nstatAddSrc(fd, NSTAT_PROVIDER_TCP, (u_int64_t)self);
	nstatAddSrc(fd, NSTAT_PROVIDER_UDP, (u_int64_t)self);
//	nstatQuerySrc(fd, NSTAT_SRC_REF_ALL, ctx);
}

- (void)closeNetStat
{
	if (self.netStat) {
		CFSocketInvalidate(self.netStat);
		CFRelease(self.netStat);
		self.netStat = 0;
	}
}

- (instancetype)initProcArrayWithIconSize:(CGFloat)size
{
	self = [super init];
	if (!self) return nil;
	self.procs = [NSMutableArray arrayWithCapacity:300];
	self.nstats = [NSMutableDictionary dictionaryWithCapacity:200];
	self.iconSize = size;
	NSProcessInfo *procinfo = [NSProcessInfo processInfo];
	self.memTotal = procinfo.physicalMemory;
	self.coresCount = procinfo.processorCount;
	// Connect to netstat kernel extension
	self.netStat = 0;
	self.netStatAddr = 0;
	[self openNetStat];
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
			proc.tcp = 0;
			proc.udp = 0;
		}
	}
	free(kp);
	[self refreshMemStats];
	// Calculate netstat totals and refresh all sources
	int fd = CFSocketGetNative(self.netStat);
	for (NSValue *val in self.nstats.allValues) {
		PSCounts cnt = val.countsValue;
		PSProc *proc = [self procForPid:cnt.pid];
		if (proc) {
			proc->netstat.rxpackets += cnt.rxpackets;
			proc->netstat.rxbytes   += cnt.rxbytes;
			proc->netstat.txpackets += cnt.txpackets;
			proc->netstat.txbytes   += cnt.txbytes;
			if (cnt.provider == NSTAT_PROVIDER_TCP)
				proc.tcp++;
			if (cnt.provider == NSTAT_PROVIDER_UDP)
				proc.udp++;
			proc.moredata = [NSString stringWithFormat:@"%d/%d", proc.tcp, proc.udp];
			if (fd != -1) {
//				if (cnt.pid == 1)
//					nstatGetSrcDesc(fd, cnt.provider, cnt.srcref);
//				else
					nstatQuerySrc(fd, cnt.srcref, cnt.srcref);
			}
		}
	}
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
	[self closeNetStat];
	[_nstats release];
	[_procs release];
	[super dealloc];
}

@end
