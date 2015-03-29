#import "Sock.h"
#import <arpa/inet.h>
#import <netdb.h>
#import "proc_info.h"

//extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
//extern int proc_listallpids(void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
//extern int proc_listpgrppids(pid_t pgrpid, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
//extern int proc_listchildpids(pid_t ppid, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_1);
extern int proc_pidinfo(int pid, int flavor, uint64_t arg,  void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
extern int proc_pidfdinfo(int pid, int fd, int flavor, void * buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
//extern int proc_pidfileportinfo(int pid, uint32_t fileport, int flavor, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
//extern int proc_name(int pid, void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
//extern int proc_regionfilename(int pid, uint64_t address, void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
//extern int proc_kmsgbuf(void * buffer, uint32_t buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
//extern int proc_libversion(int *major, int * minor) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

@implementation PSSock

- (instancetype)initWithPid:(pid_t)pid fd:(int32_t)fd type:(uint32_t)type
{
	NSString *name = nil, *stype = nil;
	UIColor *color = [UIColor blackColor];
	if (type == PROX_FDTYPE_VNODE) {
		struct vnode_fdinfowithpath info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDVNODEPATHINFO, &info, PROC_PIDFDVNODEPATHINFO_SIZE) != PROC_PIDFDVNODEPATHINFO_SIZE)
			return nil;
		name = [NSString stringWithCString:info.pvip.vip_path encoding:NSUTF8StringEncoding];
		name = [PSSymLink simplifyPathName:name];
		stype = @"VNODE";
	} else if (type == PROX_FDTYPE_PIPE) {
		struct pipe_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDPIPEINFO, &info, PROC_PIDFDPIPEINFO_SIZE) != PROC_PIDFDPIPEINFO_SIZE)
			return nil;
		name = [NSString stringWithFormat:@"%llX -> %llX %s", info.pipeinfo.pipe_handle, info.pipeinfo.pipe_peerhandle, (info.pipeinfo.pipe_status & 8) ? "Listening" : ""];
		stype = @"PIPE";
		color = [UIColor blueColor];
	} else if (type == PROX_FDTYPE_SOCKET) {
		char lip[INET_ADDRSTRLEN] = "", fip[INET_ADDRSTRLEN] = "";
		struct in_sockinfo *s;
		struct socket_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, &info, PROC_PIDFDSOCKETINFO_SIZE) != PROC_PIDFDSOCKETINFO_SIZE)
			return nil;
		switch (info.psi.soi_kind) {
		case SOCKINFO_TCP:	// Type: TCP4
		case SOCKINFO_IN:	// Type: UDP4
			s = info.psi.soi_kind == SOCKINFO_TCP ? &info.psi.soi_proto.pri_tcp.tcpsi_ini : &info.psi.soi_proto.pri_in;
			if (info.psi.soi_family == AF_INET) {
				inet_ntop(info.psi.soi_family, &s->insi_faddr.ina_46.i46a_addr4, fip, INET_ADDRSTRLEN);
				inet_ntop(info.psi.soi_family, &s->insi_laddr.ina_46.i46a_addr4, lip, INET_ADDRSTRLEN);
			}
			if (info.psi.soi_family == AF_INET6) {
				inet_ntop(info.psi.soi_family, &s->insi_faddr.ina_6, fip, INET_ADDRSTRLEN);
				inet_ntop(info.psi.soi_family, &s->insi_laddr.ina_6, lip, INET_ADDRSTRLEN);
			}
			struct servent any = {"*"};	// \u2731
			struct servent *lsp = 0, *fsp = 0;
			lsp = s->insi_lport ? getservbyport(s->insi_lport, 0) : &any;
			fsp = s->insi_fport ? getservbyport(s->insi_fport, 0) : &any;
			stype = (info.psi.soi_kind == SOCKINFO_TCP) ? @"TCP" : @"UDP";
			if (info.psi.soi_family == AF_INET6)
				stype = [stype stringByAppendingString:@"6"];
			if (lsp) name = [NSString stringWithFormat:@"%s:%s -> ", lip, lsp->s_name];
				else name = [NSString stringWithFormat:@"%s:%d -> ", lip, ntohs(s->insi_lport)];
			if (!s->insi_fport) name = [name stringByAppendingString:@"Listening"]; else
			if (fsp) name = [name stringByAppendingFormat:@"%s:%s", fip, fsp->s_name];
				else name = [name stringByAppendingFormat:@"%s:%d", fip, ntohs(s->insi_fport)];
			color = [UIColor colorWithRed:.0 green:.5 blue:.0 alpha:1.0];
			break;
		case SOCKINFO_UN: {
			if (!info.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path[0] &&
				!info.psi.soi_proto.pri_un.unsi_caddr.ua_sun.sun_path[0]) return nil;
			stype = @"UNIX";
			switch (info.psi.soi_type) {
			case SOCK_STREAM:	name = @"STREAM"; break;
			case SOCK_DGRAM:	name = @"DGRAM"; break;
			case SOCK_RAW:		name = @"RAW"; break;
			case SOCK_RDM:		name = @"RDM"; break;
			case SOCK_SEQPACKET:name = @"SEQPACKET"; break;
			default: name = @"";
			}
			NSString *server = [NSString stringWithCString:info.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path encoding:NSUTF8StringEncoding],
					 *client = [NSString stringWithCString:info.psi.soi_proto.pri_un.unsi_caddr.ua_sun.sun_path encoding:NSUTF8StringEncoding];
			name = [name stringByAppendingFormat:@" %@ -> %@", [PSSymLink simplifyPathName:server], [PSSymLink simplifyPathName:client]];
			color = [UIColor brownColor];
			break; }
		case SOCKINFO_GENERIC:
			name = [NSString stringWithFormat:@"GENERIC: %d", info.psi.soi_family];
			stype = @"GEN";
			break;
		case SOCKINFO_NDRV:
			name = [NSString stringWithFormat:@"NDRV: %d", info.psi.soi_family];
			stype = @"NDRV";
			break;
		case SOCKINFO_KERN_CTL:
			name = [NSString stringWithFormat:@"KEXT %s", info.psi.soi_proto.pri_kern_ctl.kcsi_name];
			stype = @"KCTL";
			color = [UIColor orangeColor];
			break;
		case SOCKINFO_KERN_EVENT: {
			struct kern_event_info *ki = &info.psi.soi_proto.pri_kern_event;
			NSString *kvendor = [NSString stringWithFormat:@"%d", ki->kesi_vendor_code_filter];
			NSString *kclass  = [NSString stringWithFormat:@"%d", ki->kesi_class_filter];
			NSString *ksubcls = [NSString stringWithFormat:@"%d", ki->kesi_subclass_filter];
			if (ki->kesi_vendor_code_filter == KEV_VENDOR_APPLE)	kvendor = @"APPLE";
			if (ki->kesi_vendor_code_filter == KEV_ANY_VENDOR)		kvendor = @"ANY";
			if (ki->kesi_class_filter == KEV_ANY_CLASS)				kclass  = @"ANY";
			if (ki->kesi_subclass_filter == KEV_ANY_SUBCLASS)		ksubcls = @"ANY";
			switch (ki->kesi_class_filter) {
			case KEV_NETWORK_CLASS:				kclass = @"NETWORK";
				switch (ki->kesi_subclass_filter) {
				case KEV_INET_SUBCLASS:			ksubcls = @"INET"; break;
				case KEV_DL_SUBCLASS:			ksubcls = @"DATALINK"; break;
				case KEV_NETPOLICY_SUBCLASS:	ksubcls = @"POLICY"; break;
				case KEV_ATALK_SUBCLASS:		ksubcls = @"APPLETALK"; break;
				case KEV_INET6_SUBCLASS:		ksubcls = @"INET6"; break;
				case KEV_LOG_SUBCLASS:			ksubcls = @"LOG"; break;
				} break;
			case KEV_IOKIT_CLASS:				kclass = @"IOKIT"; break;
			case KEV_SYSTEM_CLASS:				kclass = @"SYSTEM";
				switch (ki->kesi_subclass_filter) {
				case KEV_CTL_SUBCLASS:			ksubcls = @"CTL"; break;
				case KEV_MEMORYSTATUS_SUBCLASS:	ksubcls = @"MEMORYSTATUS"; break;
				} break;
			case KEV_APPLESHARE_CLASS:			kclass = @"APPLESHARE"; break;
			case KEV_FIREWALL_CLASS:			kclass = @"FIREWALL";
				switch (ki->kesi_subclass_filter) {
				case KEV_IPFW_SUBCLASS:			ksubcls = @"IPFW"; break;
				case KEV_IP6FW_SUBCLASS:		ksubcls = @"IP6FW"; break;
				} break;
			case KEV_IEEE80211_CLASS:			kclass = @"WIFI"; break;
			}
			name = [NSString stringWithFormat:@"%@:%@:%@", kvendor, kclass, ksubcls];
			stype = @"KEVNT";
			color = [UIColor redColor];
			break; }
		}
	}
	if (!name)
		return nil;
	switch (fd) {
	case 0: name = [name stringByAppendingString:@" [stdin]"]; break;
	case 1: name = [name stringByAppendingString:@" [stdout]"]; break;
	case 2: name = [name stringByAppendingString:@" [stderr]"]; break;
	}
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.fd = fd;
		self.type = type;
		self.stype = stype;
		self.color = color;
		self.name = name;
	}
	return self;
}

+ (instancetype)psSockWithPid:(pid_t)pid fd:(int32_t)fd type:(uint32_t)type
{
	return [[[PSSock alloc] initWithPid:pid fd:fd type:type] autorelease];
}

- (void)dealloc
{
	[_name release];
	[_stype release];
	[_color release];
	[super dealloc];
}

@end

@implementation PSSockArray

- (instancetype)initSockArrayWithPid:(pid_t)pid
{
	if (self = [super init]) {
		self.pid = pid;
		self.socks = [NSMutableArray arrayWithCapacity:200];
	}
	return self;
}

+ (instancetype)psSockArrayWithPid:(pid_t)pid
{
	return [[[PSSockArray alloc] initSockArrayWithPid:pid] autorelease];
}

- (int)refresh
{
	// Remove closed sockets
	[self.socks filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(PSSock *obj, NSDictionary *bind) {
		return obj.display != ProcDisplayTerminated;
	}]];
	[self setAllDisplayed:ProcDisplayTerminated];
	// Get buffer size
	int bufSize = proc_pidinfo(self.pid, PROC_PIDLISTFDS, 0, 0, 0);
	if (bufSize <= 0)
		return EPERM;
	// Get socket list and update the socks array
	struct proc_fdinfo *fdinfo = (struct proc_fdinfo *)malloc(bufSize);
	if (!fdinfo)
		return ENOMEM;
	if (proc_pidinfo(self.pid, PROC_PIDLISTFDS, 0, fdinfo, bufSize) > 0) {
		for (int i = 0; i < bufSize / PROC_PIDLISTFD_SIZE; i++) {
			PSSock *sock = [self sockForFd:fdinfo[i].proc_fd];
			if (!sock) {
				sock = [PSSock psSockWithPid:self.pid fd:fdinfo[i].proc_fd type:fdinfo[i].proc_fdtype];
				if (sock) [self.socks addObject:sock];
			} else if (sock.display != ProcDisplayStarted)
				sock.display = ProcDisplayUser;
		}
	}
	free(fdinfo);
	return 0;
}

- (void)sortUsingComparator:(NSComparator)comp desc:(BOOL)desc
{
	if (desc) {
		[self.socks sortUsingComparator:^NSComparisonResult(id a, id b) { return comp(b, a); }];
	} else
		[self.socks sortUsingComparator:comp];
}

- (void)setAllDisplayed:(display_t)display
{
	for (PSSock *sock in self.socks)
		sock.display = display;
}

- (NSUInteger)indexOfDisplayed:(display_t)display
{
	return [self.socks indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return ((PSSock *)obj).display == display;
	}];
}

- (NSUInteger)count
{
	return self.socks.count;
}

- (PSSock *)objectAtIndexedSubscript:(NSUInteger)idx
{
	return (PSSock *)[self.socks objectAtIndex:idx];
}

- (PSSock *)sockForFd:(int32_t)fd
{
	NSUInteger idx = [self.socks indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return ((PSSock *)obj).fd == fd;
	}];
	return idx == NSNotFound ? nil : (PSSock *)[self.socks objectAtIndex:idx];
}

- (void)dealloc
{
	[_socks release];
	[super dealloc];
}

@end
