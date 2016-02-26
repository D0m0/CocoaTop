#import <sys/utsname.h>
#import <sys/ioctl.h>
#import <sys/socket.h>
#import "sys/kern_control.h"
#import "sys/sys_domain.h"
#define PRIVATE
#import "Compat.h"
#import "net/ntstat.h"
//#import <mach/mach_init.h>
//#import <mach/mach_host.h>
//#import <mach/host_info.h>
#import "ProcArray.h"
#import "NetArray.h"

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
//	CFDataRef data = CFDataCreate(NULL, &aasreq, sizeof(aasreq));
//	CFSocketError err = CFSocketSendData(s, NULL, data, 0);
//	CFRelease(data);
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
	PSNetArray *self = (__bridge PSNetArray *)info;
	NSValue *srcval;
	int fd = CFSocketGetNative(s);
	nstat_msg_hdr *ns = (nstat_msg_hdr *)CFDataGetBytePtr((CFDataRef)data);
	int len = CFDataGetLength((CFDataRef)data);

	if (!len || callbackType != kCFSocketDataCallBack) {
		// 100% working hack: if an empty packet comes in, we should just reconnect
		NSLog(@"NSTAT: callbackType=%lu len=%d, reconnecting...", callbackType, len);
		[self reopen];
		return;
	}
	switch (ns->type) {
	case NSTAT_MSG_TYPE_SRC_ADDED: {
		nstat_msg_src_added *nsa = (nstat_msg_src_added *)ns;
		nstatGetSrcDesc(fd, nsa->provider, nsa->srcref);
		break; }
	case NSTAT_MSG_TYPE_SRC_REMOVED: {
		nstat_msg_src_removed *nsr = (nstat_msg_src_removed *)ns;
		if ((srcval = self.nstats[@(nsr->srcref)])) {
			PSCounts cnt = srcval.countsValue;
			cnt.provider = NSTAT_PROVIDER_NONE;
			self.nstats[@(nsr->srcref)] = [NSValue valueWithCounts:cnt];
		}
		break; }
	case NSTAT_MSG_TYPE_SRC_DESC: {
		nstat_msg_src_description *nmsd = (nstat_msg_src_description *)ns;
		PSCounts cnt = {-1, nmsd->provider, nmsd->srcref};
		if ((srcval = self.nstats[@(nmsd->srcref)]))
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
		if ((srcval = self.nstats[@(cnts->srcref)])) {
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

@implementation PSNetArray

- (void)close
{
	if (self.netStat) {
		CFSocketInvalidate(self.netStat);
		CFRelease(self.netStat);
		self.netStat = 0;
	}
}

- (void)reopen
{
	[self close];
	CFSocketContext ctx = {0, (__bridge void *)self};
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
			[self close];
			return;
		}
		struct sockaddr_ctl sc = {sizeof(sc), AF_SYSTEM, AF_SYS_CONTROL, ctlInfo.ctl_id, 0};
		self.netStatAddr = CFDataCreate(0, (const UInt8 *)&sc, sizeof(sc));
	}
	// Make a connect-callback, then do nstatAddSrc/nstatQuerySrc in the callback???
	CFSocketError err = CFSocketConnectToAddress(self.netStat, self.netStatAddr, .1);
	if (err != kCFSocketSuccess) {
		NSLog(@"NSTAT CFSocketConnectToAddress err=%ld", err);
		[self close];
		return;
	}
	nstatAddSrc(fd, NSTAT_PROVIDER_TCP, (u_int64_t)self);
	nstatAddSrc(fd, NSTAT_PROVIDER_UDP, (u_int64_t)self);
//	nstatQuerySrc(fd, NSTAT_SRC_REF_ALL, ctx);
}

- (instancetype)initNetArray
{
	self = [super init];
	if (!self) return nil;
	self.nstats = [NSMutableDictionary dictionaryWithCapacity:200];
	self.netStat = 0;
	self.netStatAddr = 0;
	[self reopen];
	return self;
}

+ (instancetype)psNetArray
{
	return [[PSNetArray alloc] initNetArray];
}

- (void)query
{
	// Query all sources
	int fd = CFSocketGetNative(self.netStat);
	if (fd != -1)
		for (NSValue *val in self.nstats.allValues) {
			PSCounts cnt = val.countsValue;
			if (cnt.pid == 1)
				nstatGetSrcDesc(fd, cnt.provider, cnt.srcref);
			else
				nstatQuerySrc(fd, cnt.srcref, cnt.srcref);
		}
}

- (void)refresh:(PSProcArray *)procs
{
	// Update all process statistics
	for (NSNumber *key in self.nstats.allKeys) {
		PSCounts cnt = ((NSValue *)self.nstats[key]).countsValue;
		PSProc *proc = [procs procForPid:cnt.pid];
		if (proc) {
			proc->netstat.rxpackets += cnt.rxpackets; proc->netstat.rxbytes += cnt.rxbytes;
			proc->netstat.txpackets += cnt.txpackets; proc->netstat.txbytes += cnt.txbytes;
			// Removed sources also go to cache
			if (cnt.provider == NSTAT_PROVIDER_NONE) {
				proc->netstat_cache.rxpackets += cnt.rxpackets; proc->netstat_cache.rxbytes += cnt.rxbytes;
				proc->netstat_cache.txpackets += cnt.txpackets; proc->netstat_cache.txbytes += cnt.txbytes;
			}
		}
		// Remove closed source
		if (cnt.provider == NSTAT_PROVIDER_NONE)
			[self.nstats removeObjectForKey:key];
	}
}

- (void)dealloc
{
	[self close];
}

@end
