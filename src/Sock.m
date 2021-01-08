#import "Sock.h"
#import "ProcArray.h"
#import <mach-o/dyld_images.h>
#import <mach/thread_info.h>
#import <arpa/inet.h>
#import <sys/syscall.h>
#import <netdb.h>
#import "sys/proc_info.h"
#import "sys/libproc.h"
#import "sys/dyld64.h"
#import "kern/debug.h"
#import "xpc/xpc.h"

#ifndef SYS_stack_snapshot 
#define SYS_stack_snapshot 365
#endif

static UIColor *_redColor() {
    if (@available(iOS 7, *)) {
        return [UIColor systemRedColor];
    } else {
        return [UIColor redColor];
    }
}

static UIColor *_orangeColor() {
    if (@available(iOS 7, *)) {
        return [UIColor systemOrangeColor];
    } else {
        return [UIColor orangeColor];
    }
}

static UIColor *_labelColor() {
    if (@available(iOS 13, *)) {
        return [UIColor labelColor];
    } else {
        return [UIColor blackColor];
    }
}

static UIColor *_blueColor() {
    if (@available(iOS 7, *)) {
        return [UIColor systemBlueColor];
    } else {
        return [UIColor blueColor];
    }
}

static UIColor *_grayColor() {
    if (@available(iOS 13, *)) {
        return [UIColor systemGrayColor];
    } else {
        return [UIColor grayColor];
    }
}

static UIColor *_greenColor() {
    if (@available(iOS 13, *)) {
        return [UIColor colorWithDynamicProvider:^(UITraitCollection *collection) {
            if (collection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.12 green:0.8 blue:0.12 alpha:1];
            } else {
                return [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
            }
        }];
    } else {
        return [UIColor colorWithRed:.0 green:.5 blue:.0 alpha:1.0];
    }
}

kern_return_t
_task_for_pid(pid_t pid, task_port_t *target) {
    kern_return_t ret = task_for_pid(mach_task_self(), pid, target);
    if (ret != KERN_SUCCESS && pid == 0) {
        ret = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, target);
    }
    return ret;
}

NSString *psGetProcessName(struct extern_proc *ep)
{
	static pid_t pid = -1;
	static NSString *procname = 0;
	if (ep->p_pid == pid)
		return procname;
	char path[MAXPATHLEN];
	if (proc_pidpath(ep->p_pid, path, sizeof(path))) {
		char *last = strrchr(path, '/');
		procname = [NSString stringWithUTF8String:(last ? last + 1 : path)];
	} else {
		ep->p_comm[MAXCOMLEN] = 0;
		procname = [NSString stringWithUTF8String:ep->p_comm];
	}
	pid = ep->p_pid;
	return procname;
}

@implementation PSSock
+ (int)refreshArray:(PSSockArray *)socks { return 0; }
- (NSString *)description { return _name; }
@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//  SUMMARY PAGE

@implementation PSSockSummary

- (instancetype)initWithProc:(PSProc *)proc column:(PSColumn *)col
{
	if (self = [super init]) {
		self.display = ProcDisplayNormal;
		self.proc = proc;
		self.col = col;
		self.name = col.fullname;
	}
	return self;
}

+ (instancetype)psSockWithProc:(PSProc *)proc column:(PSColumn *)col
{
	return [[PSSockSummary alloc] initWithProc:proc column:col];
}

+ (int)refreshArray:(PSSockArray *)socks
{
	[socks.socks removeAllObjects];
	for (PSColumn *col in [PSColumn psGetAllColumns]) if (!(col.style & ColumnStyleNoSummary)) {
		id sock = [PSSockSummary psSockWithProc:socks.proc column:col];
		if (sock) [socks.socks addObject:sock];
	}
	return 0;
}

@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//  THREADS PAGE

int stack_snapshot(int pid, char *tracebuf, int bufsize, int options)
{
	return syscall(SYS_stack_snapshot, pid, tracebuf, bufsize, options);
}

@implementation PSSockThreads

- (instancetype)initWithId:(uint64_t)tid
{
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.name = [NSString stringWithFormat:@"TID: %llX", tid];
		self.tid = tid;
	}
	return self;
}

+ (instancetype)psSockWithId:(uint64_t)tid
{
	return [[PSSockThreads alloc] initWithId:tid];
}

/*
struct frame32 {
	uint32_t	retaddr;
	uint32_t	fp;
};

struct frame64 {
	uint64_t	retaddr;
	uint64_t	fp;
};
*/

void dump(unsigned char *b, int s)
{
	for (int i = 0; i < s/16; i++) {
		NSLog(@"%02X %02X %02X %02X - %02X %02X %02X %02X - %02X %02X %02X %02X - %02X %02X %02X %02X", b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]);
		b += 16;
	}
}

+ (int)refreshArray:(PSSockArray *)socks
{
/*
	unsigned char buf[0x10000], *cur = buf;
	int size = stack_snapshot(socks.proc.pid, (char *)buf, sizeof(buf), 100);
	if (size > 0)
	while (cur < buf + size) {
		struct task_snapshot *ts = (struct task_snapshot *)cur;
		struct thread_snapshot *ths = (struct thread_snapshot *)cur;
		switch (ts->snapshot_magic) {
		case STACKSHOT_TASK_SNAPSHOT_MAGIC:
			NSLog(@"PID: %d (%s)", ts->pid, ts->p_comm);
			NSLog(@"Flags: %x, nloadinfos: %d", ts->ss_flags, ts->nloadinfos);
			dump(cur, sizeof(struct task_snapshot));
			cur += sizeof(struct task_snapshot);
			break;
		case STACKSHOT_THREAD_SNAPSHOT_MAGIC:
			NSLog(@"Thread ID: %llx, flags: %x, state: %x, Frames: %d kernel %d user", ths->thread_id, ths->ss_flags, ths->state, ths->nkern_frames, ths->nuser_frames);
			dump(cur, sizeof(struct thread_snapshot) + 246);
			//if (ths->wait_event) printf ("\tWaiting on: 0x%x ", ths->wait_event);
			//if (ths->continuation) printf ("\tContinuation: %p\n", ths->continuation);
		//if ( g_OsVer == 8 ) *voffs = 65;
		//if ( g_OsVer == 9 ) *voffs = 69;
		//if ( g_OsVer == 10 ) *voffs = 311;
			cur += sizeof(struct thread_snapshot) + 246;	//=311
			cur += ths->nuser_frames * (socks.proc.flags & P_LP64 ? sizeof(struct frame64) : sizeof(struct frame32));
			cur += ths->nkern_frames * sizeof(struct frame64);
			break;
		case STACKSHOT_MEM_AND_IO_SNAPSHOT_MAGIC:
			NSLog(@"Mem: %x", ts->snapshot_magic);
			dump(cur, sizeof(struct mem_and_io_snapshot) + 16);
			cur += sizeof(struct mem_and_io_snapshot) + 16;
			break;
		default:
			NSLog(@"%x Unk: %x", cur-buf, ts->snapshot_magic);
			cur++;
		}
	}
*/
	task_port_t task;
    if (_task_for_pid(socks.proc.pid, &task) != KERN_SUCCESS)
		return EPERM;
	thread_port_array_t thread_list;
	unsigned int thread_count;
	if (task_threads(task, &thread_list, &thread_count) != KERN_SUCCESS) {
		mach_port_deallocate(mach_task_self(), task);
		return ENOMEM;
	}
	for (unsigned int j = 0; j < thread_count; j++) {
		struct thread_identifier_info tii = {0};
		struct thread_basic_info tbi = {{0}};
		unsigned int info_count = THREAD_IDENTIFIER_INFO_COUNT;
		thread_info(thread_list[j], THREAD_IDENTIFIER_INFO, (thread_info_t)&tii, &info_count);
		info_count = THREAD_BASIC_INFO_COUNT;
		thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)&tbi, &info_count);
		if (tii.thread_id) {
			PSSockThreads *sock = (PSSockThreads *)[socks objectPassingTest:^BOOL(PSSockThreads *obj, NSUInteger idx, BOOL *stop) {
				return obj.tid == tii.thread_id;
			}];
			if (!sock) {
				sock = [PSSockThreads psSockWithId:tii.thread_id];
				if (sock) [socks.socks addObject:sock];
			} else if (sock.display != ProcDisplayStarted)
				sock.display = ProcDisplayUser;
			sock->tbi = tbi;
			// Roundup time: 100's of a second
			sock.ptime = (tbi.system_time.seconds + tbi.user_time.seconds) * 100 + (tbi.system_time.microseconds + tbi.user_time.microseconds + 5000) / 10000;
			sock.prio = mach_thread_priority(thread_list[j], tbi.policy);
			switch (sock->tbi.run_state) {
            case TH_STATE_RUNNING:			sock.color = _redColor();break;//sock.color = [UIColor redColor]; break;
            case TH_STATE_UNINTERRUPTIBLE:	sock.color = _orangeColor(); break;//[UIColor orangeColor]; break;
            case TH_STATE_WAITING:			sock.color = sock->tbi.suspend_count ? _blueColor() : _labelColor();break;//[UIColor blueColor] : [UIColor blackColor]; break;
			case TH_STATE_STOPPED:
			case TH_STATE_HALTED:			sock.color = [UIColor brownColor]; break;
            default:						sock.color = _grayColor();//[UIColor grayColor];
			}
			// Get thread name
			sock.name = @"-";
			struct proc_threadinfo pth = {0};
			proc_pidinfo(socks.proc.pid, PROC_PIDTHREADINFO, tii.thread_handle, &pth, sizeof(pth));
			if (pth.pth_name[0])
				sock.name = [NSString stringWithUTF8String:pth.pth_name];
			// Get dispatch queue name
			NSString *dispQueue = nil;
			int bits = socks.proc.flags & P_LP64 ? sizeof(uint64_t) : sizeof(uint32_t);
			uint64_t addr = tii.dispatch_qaddr;
			mach_vm_size_t size;
			if (addr && mach_vm_read_overwrite(task, addr, bits, (mach_vm_address_t)&addr, &size) == KERN_SUCCESS) {
				NSNumber *dispQueueAddr = [NSNumber numberWithUnsignedLongLong:addr];
				// Get it from our cache
				dispQueue = socks.proc.dispQueue[dispQueueAddr];
				if (!dispQueue) {
					char buf[256] = {0};
					if (socks.proc.flags & P_LP64) {
						// This is just a hard-coded offset to where the name pointer should be, same for all arm64 systems
						if (addr && mach_vm_read_overwrite(task, addr + 0x78, bits, (mach_vm_address_t)&addr, &size) == KERN_SUCCESS)
						if (addr && mach_vm_read_overwrite(task, addr, sizeof(buf)-1, (mach_vm_address_t)buf, &size) == KERN_SUCCESS)
							dispQueue = [NSString stringWithUTF8String:buf];
					} else {
						// This is a super-hacky hack which works on all 32 bit iOSes!
						if (mach_vm_read_overwrite(task, addr, sizeof(buf), (mach_vm_address_t)buf, &size) == KERN_SUCCESS) {
#if 0
#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0
							uint64_t addr = (uint64_t)dispatch_queue_get_label((dispatch_queue_t)buf);
#else
							uint64_t addr = (uint64_t)dispatch_queue_get_label((__bridge dispatch_queue_t)(void *)buf);
#endif
#endif
                            uint64_t addr;
                            //if (@available(iOS 6, *)) {
                                addr = (uint64_t)dispatch_queue_get_label((__bridge dispatch_queue_t)(void *)buf);
                            //} else {
                                //addr = (uint64_t)dispatch_queue_get_label((dispatch_queue_t)buf);
                            //}
							// addr=buf+0x38 on iOS5
							if (addr > (uint64_t)buf && addr < (uint64_t)buf + sizeof(buf))
								dispQueue = [NSString stringWithUTF8String:(char *)addr];
							// addr=buf[0x3C] on iOS7, addr=buf[0x48] on iOS8
							else if (addr && mach_vm_read_overwrite(task, addr, sizeof(buf)-1, (mach_vm_address_t)buf, &size) == KERN_SUCCESS)
								dispQueue = [NSString stringWithUTF8String:buf];
						}
					}
					[socks.proc.dispQueue setObject:dispQueue ? dispQueue : @"" forKey:dispQueueAddr];
				}
			}
			if (dispQueue.length)
				sock.name = [sock.name stringByAppendingFormat:@" [DQ:%@]", dispQueue];
		}
		mach_port_deallocate(mach_task_self(), thread_list[j]);
	}
	vm_deallocate(mach_task_self(), (vm_address_t)thread_list, sizeof(*thread_list) * thread_count);
	mach_port_deallocate(mach_task_self(), task);
	return 0;
}

@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//  OPEN FILES PAGE

@implementation PSSockFiles

- (instancetype)initWithSocks:(PSSockArray *)socks fd:(int32_t)fd type:(uint32_t)type
{
	pid_t pid = socks.proc.pid;
	NSMutableString *name = nil;
    UIColor *color = _labelColor();//[UIColor blackColor];
	uint32_t flags = 0;
	uint64_t node = 0;
	char *stype = nil;

	if (type == PROX_FDTYPE_VNODE) {
		struct vnode_fdinfowithpath info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDVNODEPATHINFO, &info, PROC_PIDFDVNODEPATHINFO_SIZE) != PROC_PIDFDVNODEPATHINFO_SIZE)
			return nil;
		name = [[PSSymLink simplifyPathName:[NSString stringWithUTF8String:info.pvip.vip_path]] mutableCopy];
		stype = "VNODE";
		flags = info.pfi.fi_openflags;
		node = info.pvip.vip_vi.vi_stat.vst_ino;
	} else if (type == PROX_FDTYPE_PIPE) {
		struct pipe_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDPIPEINFO, &info, PROC_PIDFDPIPEINFO_SIZE) != PROC_PIDFDPIPEINFO_SIZE)
			return nil;
		NSString *partner = socks.objects[@(info.pipeinfo.pipe_peerhandle)];
		name = [NSMutableString stringWithFormat:@"\u2192 %@", partner ? partner : @"<Unknown>"];
		if (info.pipeinfo.pipe_status & PIPE_WANTR)			[name appendString:@" READ"];
		if (info.pipeinfo.pipe_status & PIPE_WANTW)			[name appendString:@" WRITE"];
		if (info.pipeinfo.pipe_status & PIPE_SEL)			[name appendString:@" SELECT"];
		if (info.pipeinfo.pipe_status & PIPE_EOF)			[name appendString:@" EOF"];
		if (info.pipeinfo.pipe_status & PIPE_KNOTE)			[name appendString:@" KNOTE"];
		if (info.pipeinfo.pipe_status & PIPE_DRAIN)			[name appendString:@" DRAIN"];
		if (info.pipeinfo.pipe_status & PIPE_DEAD)			[name appendString:@" DEAD"];
		stype = "PIPE";
        color = _blueColor();//[UIColor blueColor];
		flags = info.pfi.fi_openflags;
		node = info.pipeinfo.pipe_handle;
	} else if (type == PROX_FDTYPE_KQUEUE) {
		struct kqueue_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDKQUEUEINFO, &info, PROC_PIDFDKQUEUEINFO_SIZE) != PROC_PIDFDKQUEUEINFO_SIZE)
			return nil;
		name = [info.kqueueinfo.kq_state & PROC_KQUEUE_64 ? @"KQUEUE64:" : info.kqueueinfo.kq_state & PROC_KQUEUE_32 ? @"KQUEUE32:" : @"KQUEUE:" mutableCopy];
		if (info.kqueueinfo.kq_state & PROC_KQUEUE_SELECT)	[name appendString:@" SELECT"];
		if (info.kqueueinfo.kq_state & PROC_KQUEUE_SLEEP)	[name appendString:@" SLEEP"];
		if (info.kqueueinfo.kq_state & PROC_KQUEUE_QOS)		[name appendString:@" QOS"];
		if (!(info.kqueueinfo.kq_state & ~(PROC_KQUEUE_32 | PROC_KQUEUE_64))) [name appendString:@" SUSPENDED"];
		stype = "QUEUE";
        color = _grayColor();//[UIColor grayColor];
		flags = info.pfi.fi_openflags;
		node = info.kqueueinfo.kq_state;
	} else if (type == PROX_FDTYPE_SOCKET) {
		char lip[INET_ADDRSTRLEN] = "", fip[INET_ADDRSTRLEN] = "";
		struct in_sockinfo *s;
		struct socket_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, &info, PROC_PIDFDSOCKETINFO_SIZE) != PROC_PIDFDSOCKETINFO_SIZE)
			return nil;
		switch (info.psi.soi_kind) {
		case SOCKINFO_TCP:	// Type: TCP
		case SOCKINFO_IN:	// Type: UDP
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
			if (info.psi.soi_family == AF_INET6) stype = (info.psi.soi_kind == SOCKINFO_TCP) ? "TCP6" : "UDP6";
											else stype = (info.psi.soi_kind == SOCKINFO_TCP) ? "TCP" : "UDP";
			if (lsp) name = [NSMutableString stringWithFormat:@"%s:%s \u2192 ", lip, lsp->s_name];
				else name = [NSMutableString stringWithFormat:@"%s:%d \u2192 ", lip, ntohs(s->insi_lport)];
			if (!s->insi_fport) [name appendString:@"Listening"]; else
			if (fsp) [name appendFormat:@"%s:%s", fip, fsp->s_name];
				else [name appendFormat:@"%s:%d", fip, ntohs(s->insi_fport)];
                
            color = _greenColor();//[UIColor colorWithRed:.0 green:.5 blue:.0 alpha:1.0];
			break;
		case SOCKINFO_UN: {
			stype = "UNIX";
			switch (info.psi.soi_type) {
			case SOCK_STREAM:	name = [@"STREAM" mutableCopy]; break;
			case SOCK_DGRAM:	name = [@"DGRAM" mutableCopy]; break;
			case SOCK_RAW:		name = [@"RAW" mutableCopy]; break;
			case SOCK_RDM:		name = [@"RDM" mutableCopy]; break;
			case SOCK_SEQPACKET:name = [@"SEQPACKET" mutableCopy]; break;
			default: 			name = [NSMutableString stringWithFormat:@"UNIX: %d", info.psi.soi_type];
			}
			NSString *client = [NSString stringWithUTF8String:info.psi.soi_proto.pri_un.unsi_caddr.ua_sun.sun_path],
					 *server = [NSString stringWithUTF8String:info.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path],
					*partner = socks.objects[@(info.psi.soi_proto.pri_un.unsi_conn_so)];
			[name appendFormat:@": %@ \u2192 %@ %@", [PSSymLink simplifyPathName:client], [PSSymLink simplifyPathName:server], partner ? partner : @""];
			color = [UIColor brownColor];
			break; }
		case SOCKINFO_GENERIC:
			name = [NSMutableString stringWithFormat:@"GENERIC: %d", info.psi.soi_family];
			stype = "GEN";
			break;
		case SOCKINFO_NDRV:
			name = [NSMutableString stringWithFormat:@"NDRV: %d", info.psi.soi_family];
			stype = "NDRV";
			break;
		case SOCKINFO_KERN_CTL:
			name = [NSMutableString stringWithFormat:@"KEXT: %s", info.psi.soi_proto.pri_kern_ctl.kcsi_name];
			stype = "KCTL";
            color = _orangeColor();//[UIColor orangeColor];
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
				case KEV_SOCKET_SUBCLASS:		ksubcls = @"SOCKET"; break;
				case KEV_ATALK_SUBCLASS:		ksubcls = @"APPLETALK"; break;
				case KEV_INET6_SUBCLASS:		ksubcls = @"INET6"; break;
				case KEV_ND6_SUBCLASS:			ksubcls = @"ND6"; break;
				case KEV_NECP_SUBCLASS:			ksubcls = @"NECP"; break;
				case KEV_NETAGENT_SUBCLASS:		ksubcls = @"NETAGENT"; break;
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
				switch (ki->kesi_subclass_filter) {
				case KEV_APPLE80211_EVENT_SUBCLASS: kclass = @"EVENT"; break;
				} break;
			}
			name = [NSMutableString stringWithFormat:@"%@:%@:%@", kvendor, kclass, ksubcls];
			stype = "KEVNT";
            color = _redColor();//[UIColor redColor];
			break; }
		}
		flags = info.pfi.fi_openflags;
		node = info.psi.soi_so;
	}
	if (!name)
		return nil;
	switch (fd) {
	case 0: [name appendString:@" [stdin]"]; break;
	case 1: [name appendString:@" [stdout]"]; break;
	case 2: [name appendString:@" [stderr]"]; break;
	}
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.fd = fd;
		self.type = type;
		self.stype = stype;
		self.color = color;
		self.name = [name copy];
		self.flags = flags;
		self.node = node;
	}
	return self;
}

+ (instancetype)psSock:(PSSockArray *)socks fd:(int32_t)fd type:(uint32_t)type
{
	return [[PSSockFiles alloc] initWithSocks:socks fd:fd type:type];
}

- (BOOL)updateWithPid:(pid_t)pid fd:(int32_t)fd
{
	if (self.display != ProcDisplayStarted)
		self.display = ProcDisplayUser;
	if (self.type == PROX_FDTYPE_VNODE) {
		struct vnode_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDVNODEINFO, &info, PROC_PIDFDVNODEINFO_SIZE) != PROC_PIDFDVNODEINFO_SIZE)
			return NO;
		return self.node == info.pvi.vi_stat.vst_ino;
	} else if (self.type == PROX_FDTYPE_PIPE) {
		struct pipe_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDPIPEINFO, &info, PROC_PIDFDPIPEINFO_SIZE) != PROC_PIDFDPIPEINFO_SIZE)
			return NO;
		return self.node == info.pipeinfo.pipe_handle;
	} else if (self.type == PROX_FDTYPE_SOCKET) {
		struct socket_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, &info, PROC_PIDFDSOCKETINFO_SIZE) != PROC_PIDFDSOCKETINFO_SIZE)
			return NO;
		return self.node == info.psi.soi_so;
	} else if (self.type == PROX_FDTYPE_KQUEUE) {
		struct kqueue_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDKQUEUEINFO, &info, PROC_PIDFDKQUEUEINFO_SIZE) != PROC_PIDFDKQUEUEINFO_SIZE)
			return NO;
		if (self.node == info.kqueueinfo.kq_state)
			return YES;
		self.node = info.kqueueinfo.kq_state;
		NSMutableString *name = [info.kqueueinfo.kq_state & PROC_KQUEUE_64 ? @"KQUEUE64:" : info.kqueueinfo.kq_state & PROC_KQUEUE_32 ? @"KQUEUE32:" : @"KQUEUE:" mutableCopy];
		if (info.kqueueinfo.kq_state & PROC_KQUEUE_SELECT)	[name appendString:@" SELECT"];
		if (info.kqueueinfo.kq_state & PROC_KQUEUE_SLEEP)	[name appendString:@" SLEEP"];
		if (info.kqueueinfo.kq_state & PROC_KQUEUE_QOS)		[name appendString:@" QOS"];
		if (!(info.kqueueinfo.kq_state & ~(PROC_KQUEUE_32 | PROC_KQUEUE_64))) [name appendString:@" SUSPENDED"];
		self.name = [name copy];
	}
	return YES;
}

// Get system-wide fds that can potentially be used for IPC with this process
+ (int)getKernelObjects:(NSMutableDictionary *)objects
{
	PSProcInfo *procs = [PSProcInfo psProcInfoSort:NO];
	if (procs->ret)
		return procs->ret;
	struct proc_fdinfo *fdinfo = 0;
	size_t bufSize = 0, curBufSize = 0;
	for (int i = 0; i < procs->count; i++) {
		struct extern_proc *ep = &procs->kp[i].kp_proc;
		bufSize = proc_pidinfo(ep->p_pid, PROC_PIDLISTFDS, 0, 0, 0);
		if (bufSize <= 0)
			continue;
		if (bufSize > curBufSize) {
			bufSize *= 2;
			if (fdinfo) free(fdinfo);
			fdinfo = (struct proc_fdinfo *)malloc(bufSize);
			if (!fdinfo)
				return ENOMEM;
			curBufSize = bufSize;
		}
		bufSize = proc_pidinfo(ep->p_pid, PROC_PIDLISTFDS, 0, fdinfo, bufSize);
		if (bufSize <= 0)
			continue;
		for (int j = 0; j < bufSize / PROC_PIDLISTFD_SIZE; j++) {
			int32_t fd = fdinfo[j].proc_fd;
			if (fdinfo[j].proc_fdtype == PROX_FDTYPE_PIPE) {
				struct pipe_fdinfo info;
				if (proc_pidfdinfo(ep->p_pid, fd, PROC_PIDFDPIPEINFO, &info, PROC_PIDFDPIPEINFO_SIZE) != PROC_PIDFDPIPEINFO_SIZE)
					continue;
				objects[@(info.pipeinfo.pipe_handle)] = [NSString stringWithFormat:@"[%@:%d]", psGetProcessName(ep), fd];
			} else if (fdinfo[j].proc_fdtype == PROX_FDTYPE_SOCKET) {
				struct socket_fdinfo info;
				if (proc_pidfdinfo(ep->p_pid, fd, PROC_PIDFDSOCKETINFO, &info, PROC_PIDFDSOCKETINFO_SIZE) != PROC_PIDFDSOCKETINFO_SIZE)
					continue;
				if (info.psi.soi_kind == SOCKINFO_UN && info.psi.soi_so)
					objects[@(info.psi.soi_so)] = [NSString stringWithFormat:@"[%@:%d]", psGetProcessName(ep), fd];
			}
		}
	}
	if (fdinfo) free(fdinfo);
	return 0;
}

+ (int)refreshArray:(PSSockArray *)socks
{
	if (!socks.objects) {
		socks.objects = [NSMutableDictionary dictionaryWithCapacity:1000];
		[self getKernelObjects:socks.objects];
	}
	// Get buffer size
	int bufSize = proc_pidinfo(socks.proc.pid, PROC_PIDLISTFDS, 0, 0, 0);
	if (bufSize <= 0)
		return EPERM;
	// Make sure the buffer is large enough ;)
	bufSize *= 2;
	struct proc_fdinfo *fdinfo = (struct proc_fdinfo *)malloc(bufSize);
	if (!fdinfo)
		return ENOMEM;
	// Get socket list and update the socks array
	bufSize = proc_pidinfo(socks.proc.pid, PROC_PIDLISTFDS, 0, fdinfo, bufSize);
	if (bufSize > 0) {
		int totalfds = bufSize / PROC_PIDLISTFD_SIZE;
		for (int i = 0; i < totalfds; i++) {
			PSSockFiles *sock = (PSSockFiles *)[socks objectPassingTest:^BOOL(PSSockFiles *obj, NSUInteger idx, BOOL *stop) {
				return obj.fd == fdinfo[i].proc_fd && obj.type == fdinfo[i].proc_fdtype;
			}];
			if (!sock) {
				sock = [PSSockFiles psSock:socks fd:fdinfo[i].proc_fd type:fdinfo[i].proc_fdtype];
				if (sock) [socks.socks addObject:sock];
			} else if (![sock updateWithPid:socks.proc.pid fd:fdinfo[i].proc_fd]) {
				sock.display = ProcDisplayTerminated;
				PSSockFiles *newsock = [PSSockFiles psSock:socks fd:fdinfo[i].proc_fd type:fdinfo[i].proc_fdtype];
				if (newsock) [socks.socks addObject:newsock];
			}
		}
	}
	free(fdinfo);
	return 0;
}

@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//  OPEN PORTS PAGE

@interface PSPortInfo : NSObject {
@public task_port_t task;
@public ipc_info_name_array_t table;
@public mach_msg_type_number_t count;
@public kern_return_t ret;
}
+ (instancetype)psPortInfoForPid:(pid_t)pid;
@end

@implementation PSPortInfo
- (instancetype)initPortInfoForPid:(pid_t)pid
{
	self = [super init];
	self->task = 0;
	self->table = 0;
	self->count = 0;
    self->ret = _task_for_pid(pid, &self->task);
	if (self->ret == KERN_SUCCESS) {
		ipc_info_space_t info;		// iis_genno_mask
		ipc_info_tree_name_array_t tree = 0;
		mach_msg_type_number_t treeCount = 0;
		self->ret = mach_port_space_info(self->task, &info, &self->table, &self->count, &tree, &treeCount);
		if (self->ret != KERN_SUCCESS)
			self->count = 0;
		else if (tree)
			vm_deallocate(mach_task_self(), (vm_address_t)tree, treeCount * sizeof(*tree));
	}
	return self;
}

+ (instancetype)psPortInfoForPid:(pid_t)pid
{
	return [[PSPortInfo alloc] initPortInfoForPid:pid];
}

- (void)dealloc
{
	if (table) vm_deallocate(mach_task_self(), (vm_address_t)table, count * sizeof(*table));
	if (task) mach_port_deallocate(mach_task_self(), task);
}
@end

@implementation PSSockPorts

+ (NSMutableDictionary *)getLaunchdPortNames
{
    static dispatch_queue_t launchd_pipe_queue;
    static dispatch_once_t once;
    static NSCharacterSet *MU_cset;
    static NSCharacterSet *AD_cset;
    dispatch_once(&once, ^{
        launchd_pipe_queue = dispatch_queue_create("com.sxx.queue.launchd_pipe", DISPATCH_QUEUE_SERIAL);
        MU_cset = [NSCharacterSet characterSetWithCharactersInString:@"MU"];
        AD_cset = [NSCharacterSet characterSetWithCharactersInString:@"AD"];
    });
	NSMutableDictionary *knownPorts = nil;
	int *hpipe = alloca(sizeof(int) * 2);
	pipe(hpipe);
	xpc_object_t xpc_out = 0, xpc_in = xpc_dictionary_create(0, 0, 0);
	xpc_dictionary_set_uint64(xpc_in, "handle", 0);
	xpc_dictionary_set_uint64(xpc_in, "routine", 828);
	xpc_dictionary_set_uint64(xpc_in, "subsystem", 3);
	xpc_dictionary_set_uint64(xpc_in, "type", 1);
	xpc_dictionary_set_fd(xpc_in, "fd", hpipe[1]);
	xpc_pipe_t xp = xpc_pipe_create_from_port(bootstrap_port, 0);
//	xpc_pipe_t xp = (xpc_pipe_t)_os_alloc_once_table[1].ptr[3];
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
    if (@available(iOS 6, *)) {
        size_t buf_size;
        if (@available(iOS 12, *)) {
            buf_size = 0x800000u;
        } else {
            buf_size = 0x100000u;
        }
        char *buf = (char *)malloc(buf_size);
        
        dispatch_async(launchd_pipe_queue, ^{
            off_t done = 0;
            size_t remains = buf_size;
            int fd = hpipe[0];
            while (done < buf_size) {
                ssize_t once = read(fd, buf + done, remains);
                if (once <= 0) {
                    break;
                }
                done += once;
                remains -= once;
            }
        });
        
        if (xpc_pipe_routine(xp, xpc_in, &xpc_out) || !xpc_dictionary_get_int64(xpc_out, "error")) {
            xpc_release(xpc_in);
            xpc_in = nil;
            close(hpipe[1]);
            hpipe[1] = -1;
            dispatch_sync(launchd_pipe_queue, ^{});
        }
		char *endpoints_start = strstr(buf, "\tendpoints = {");
		if (endpoints_start) {
			endpoints_start += 14;
			char *endpoints_end = strchr(endpoints_start, '}');
			if (endpoints_end)
				*endpoints_end = 0;
			PSPortInfo *ports = [PSPortInfo psPortInfoForPid:1];
			NSScanner *endpoints = [NSScanner scannerWithString:[NSString stringWithUTF8String:endpoints_start]];
			free(buf);
            buf = NULL;
			knownPorts = [NSMutableDictionary dictionaryWithCapacity:1000];
			while (!endpoints.isAtEnd) {
				mach_port_name_t port;
				NSString *name;
				if (![endpoints scanHexInt:&port]) break;
				[endpoints scanCharactersFromSet:MU_cset intoString:nil];
				[endpoints scanCharactersFromSet:AD_cset intoString:nil];
				if (![endpoints scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&name]) break;
				for (mach_msg_type_number_t i = 0; i < ports->count; i++)
					if (ports->table[i].iin_name == port) {
						knownPorts[@(ports->table[i].iin_object)] = name;
						break;
					}
			}
		}
        if (buf != NULL) {
            free(buf);
        }
    }
	if (xpc_in) xpc_release(xpc_in);
	if (xpc_out) xpc_release(xpc_out);
	xpc_release(xp);
    if (hpipe[0] != -1) {
        close(hpipe[0]);
    }
    if (hpipe[1] != -1) {
        close(hpipe[1]);
    }
//#endif
	return knownPorts;
}

const char *port_types[] = {"","(thread)","(task)","(host)","(host priv)","(processor)","(pset)","(pset name)",
	"(timer)","(paging request)","(mig)","(memory object)","(xmm pager)","(xmm kernel)","(xmm reply)","(und reply)","(host notify)",
	"(host security)","(ledger)","(master device)","(task name)","(subsystem)","(io done queue)","(semaphore)","(lock set)",
	"(clock)","(clock ctrl)","(iokit spare)","(named entry)","(iokit connect)","(iokit object)","(upl)","(xmm ctrl)",
	"(audit session)","(file)","(label handle)","(task resume)","(voucher)","(voucher attr)","(unknown)"};

- (NSString *)description
{
	if (!self.name) self.name = self.connect.length ? [self.connect copy] : @"-";
	return self.name;
}

- (instancetype)initWithTask:(task_port_t)task ipcInfo:(ipc_info_name_t *)iin name:(NSString *)name
{
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.port = iin->iin_name;
		self.object = iin->iin_object;
		self.type = iin->iin_type;
		mach_port_type_t send = iin->iin_type & MACH_PORT_TYPE_SEND_RIGHTS;
		mach_port_type_t recv = iin->iin_type & MACH_PORT_TYPE_RECEIVE;
		mach_port_type_t pset = iin->iin_type & MACH_PORT_TYPE_PORT_SET;

		natural_t object_type = 0;
		vm_offset_t object_addr = 0;
		mach_port_kernel_object(task, iin->iin_name, &object_type, (unsigned int *)&object_addr);
		self.connect = name ? [name mutableCopy] : [NSMutableString stringWithUTF8String:port_types[object_type]];
		if (pset) {
			if (!self.connect.length)
				[self.connect appendString:@"(portset)"];
			mach_port_name_array_t members = 0;
			mach_msg_type_number_t memberCount = 0;
			if (mach_port_get_set_status(task, iin->iin_name, &members, &memberCount) != KERN_SUCCESS)
				memberCount = 0;
			for (size_t i = 0; i < memberCount; i++)
				[self.connect appendFormat:@" %X", members[i]];
			if (members)
				vm_deallocate(mach_task_self(), (vm_address_t)members, memberCount * sizeof(*members));
		} else
		self.color = pset ? _orangeColor()/*[UIColor orangeColor]*/ : send && recv ? _greenColor()/*[UIColor colorWithRed:.0 green:.5 blue:.0 alpha:1.0]*/ : recv ? _blueColor()/*[UIColor blueColor]*/ : /*[UIColor blackColor]*/_labelColor();
	}
	return self;
}

+ (instancetype)psSockWithTask:(task_port_t)task ipcInfo:(ipc_info_name_t *)iin name:(NSString *)name
{
	return [[PSSockPorts alloc] initWithTask:task ipcInfo:iin name:name];
}

+ (int)refreshArray:(PSSockArray *)socks
{
	PSPortInfo *myports = [PSPortInfo psPortInfoForPid:socks.proc.pid];
	if (myports->ret != KERN_SUCCESS)
		return myports->ret;
	if (!socks.objects) socks.objects = [self getLaunchdPortNames];
	NSMutableDictionary *newPorts = [NSMutableDictionary dictionary];

	for (mach_msg_type_number_t i = 0; i < myports->count; i++) {
		natural_t object = myports->table[i].iin_object;
		if (object) {
			PSSockPorts *sock = (PSSockPorts *)[socks objectPassingTest:^BOOL(PSSockPorts *obj, NSUInteger idx, BOOL *stop) {
				return obj.object == object;
			}];
			if (!sock) {
				sock = [PSSockPorts psSockWithTask:myports->task ipcInfo:&myports->table[i] name:socks.objects[@(object)]];
				if (sock) {
					[socks.socks addObject:sock];
					newPorts[@(object)] = sock;
				}
			} else if (sock.display != ProcDisplayStarted)
				sock.display = ProcDisplayUser;
		}
	}
	if (!newPorts.count)
		return 0;

	PSProcInfo *procs = [PSProcInfo psProcInfoSort:YES];
	if (procs->ret)
		return procs->ret;
	for (int i = 0; i < procs->count; i++) {
		struct extern_proc *ep = &procs->kp[i].kp_proc;
		if (ep->p_pid != socks.proc.pid) {
			// Get process ports
			PSPortInfo *ports = [PSPortInfo psPortInfoForPid:ep->p_pid];
			for (mach_msg_type_number_t j = 0; j < ports->count; j++) {
				PSSockPorts *sock = newPorts[@(ports->table[j].iin_object)];
				if (!sock)
					continue;
				if ((sock.type & MACH_PORT_TYPE_RECEIVE) && (ports->table[j].iin_type & MACH_PORT_TYPE_SEND_RIGHTS))
					[sock.connect appendFormat:@" <%@:%X", psGetProcessName(ep), ports->table[j].iin_name];
				else if ((sock.type & MACH_PORT_TYPE_SEND_RIGHTS) && (ports->table[j].iin_type & MACH_PORT_TYPE_RECEIVE))
					[sock.connect appendFormat:@" >%@:%X", psGetProcessName(ep), ports->table[j].iin_name];
			}
		}
	}
	return 0;
}

@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//  MODULES PAGE

@implementation PSSockModules

- (instancetype)initWithRwpi:(struct proc_regionwithpathinfo *)rwpi
{
	if (!rwpi->prp_vip.vip_path[0] && !rwpi->prp_vip.vip_vi.vi_stat.vst_dev && !rwpi->prp_vip.vip_vi.vi_stat.vst_ino)
		return nil;
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.name = rwpi->prp_vip.vip_path[0] ? [PSSymLink simplifyPathName:[NSString stringWithUTF8String:rwpi->prp_vip.vip_path]] : @"<none>";
		self.bundle = [self.name lastPathComponent];
		self.addr = rwpi->prp_prinfo.pri_address;
		self.size = rwpi->prp_prinfo.pri_size;
		self.ref = rwpi->prp_prinfo.pri_ref_count;
		self.dev = rwpi->prp_vip.vip_vi.vi_stat.vst_dev;
		self.ino = rwpi->prp_vip.vip_vi.vi_stat.vst_ino;
		self.color = self.dev && self.ino ? _labelColor()/*[UIColor blackColor]*/ : _grayColor()/*[UIColor grayColor]*/;
	}
	return self;
}

+ (instancetype)psSockWithRwpi:(struct proc_regionwithpathinfo *)rwpi
{
	return [[PSSockModules alloc] initWithRwpi:rwpi];
}

- (instancetype)initWithDict:(NSDictionary *)dict 
{
	if (self = [super init]) {
		self.display = ProcDisplayUser;
		self.name = dict[@"OSBundleExecutablePath"];
		self.addr = [dict[@"OSBundleLoadAddress"] longLongValue] & 0xffffffffffffLL;
		self.size = [dict[@"OSBundleLoadSize"] longLongValue];
		self.ref = [dict[@"OSBundleRetainCount"] longValue];
//		self.dev = [dict[@"OSBundleLoadTag"] longValue];
		self.color = self.name ? _labelColor()/*[UIColor blackColor]*/ : _grayColor()/*[UIColor grayColor]*/;
		self.bundle = dict[@"CFBundleIdentifier"];
		if (!self.name) self.name = self.bundle;
	}
	return self;
}

+ (instancetype)psSockWithDict:(NSDictionary *)dict 
{
	return [[PSSockModules alloc] initWithDict:dict];
}

- (NSString *)description
{
	return self.bundle;
}

extern CFDictionaryRef OSKextCopyLoadedKextInfo(CFArrayRef kextIdentifiers, CFArrayRef infoKeys);

+ (int)refreshArray:(PSSockArray *)socks
{
	// For the kernel task we will show loaded kernel extensions
	if (socks.proc.pid == 0) {
		if (!socks.objects) {
			// CFBundleVersion OSBundleStarted
			NSArray *infoKeys = @[@"CFBundleIdentifier", @"OSBundleExecutablePath", @"OSBundleLoadAddress", @"OSBundleLoadSize", @"OSBundleLoadTag", @"OSBundleRetainCount"];
			NSDictionary *kextDict = (__bridge NSDictionary*)OSKextCopyLoadedKextInfo(0, (__bridge CFArrayRef)infoKeys);
			[kextDict enumerateKeysAndObjectsUsingBlock: ^void(NSString *key, NSDictionary *kext, BOOL *stop) {
				[socks.socks addObject:[PSSockModules psSockWithDict:kext]];
			}];
			socks.objects = [NSMutableDictionary dictionaryWithCapacity:1];
		} else {
			[socks setAllDisplayed:ProcDisplayUser];
		}
		return 0;
	}

	task_port_t task;
    if (_task_for_pid(socks.proc.pid, &task) != KERN_SUCCESS)
		return EPERM;
	task_dyld_info_data_t task_dyld_info;
	mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
	if (task_info(task, TASK_DYLD_INFO, (task_info_t)&task_dyld_info, &count) != KERN_SUCCESS) {
		mach_port_deallocate(mach_task_self(), task);
		return ENOMEM;
	}
	struct dyld_all_image_infos64 aii;
	mach_vm_size_t aiiSize = sizeof(aii);
	if (mach_vm_read_overwrite(task, task_dyld_info.all_image_info_addr, aiiSize, (mach_vm_address_t)&aii, &aiiSize) == KERN_SUCCESS) {
		mach_vm_address_t		ii;
		uint32_t				iiCount;
		mach_msg_type_number_t	iiSize;
		if (socks.proc.flags & P_LP64) {
			ii = aii.infoArray;
			iiCount = aii.infoArrayCount;
			iiSize = iiCount * sizeof(struct dyld_image_info64);
		} else {
			struct dyld_all_image_infos *aii32 = (struct dyld_all_image_infos *)&aii;
			ii = (mach_vm_address_t)aii32->infoArray;
			iiCount = aii32->infoArrayCount;
			iiSize = iiCount * sizeof(struct dyld_image_info);
		}
// If ii is NULL, it means it is being modified, come back later.
		if (mach_vm_read(task, ii, iiSize, (vm_offset_t *)&ii, &iiSize) == KERN_SUCCESS) {
			for (int i = 0; i < iiCount; i++) {
				mach_vm_address_t addr;
				mach_vm_address_t path;
				if (socks.proc.flags & P_LP64) {
					struct dyld_image_info64 *ii64 = (struct dyld_image_info64 *)ii;
					addr = ii64[i].imageLoadAddress;
					path = ii64[i].imageFilePath;
				} else {
					struct dyld_image_info *ii32 = (struct dyld_image_info *)ii;
					addr = (mach_vm_address_t)ii32[i].imageLoadAddress;
					path = (mach_vm_address_t)ii32[i].imageFilePath;
				}
				struct proc_regionwithpathinfo rwpi;
				if (proc_pidinfo(socks.proc.pid, PROC_PIDREGIONPATHINFO, addr, &rwpi, PROC_PIDREGIONPATHINFO_SIZE) != PROC_PIDREGIONPATHINFO_SIZE)
					continue;
				PSSockModules *sock = (PSSockModules *)[socks objectPassingTest:^BOOL(PSSockModules *obj, NSUInteger idx, BOOL *stop) {
					return obj.addr == addr;
				}];
				if (!sock) {
					// dyld cache has the info that proc_pidinfo doesn't give
					if (!rwpi.prp_vip.vip_path[0]) {
						mach_vm_size_t size3;
						if (mach_vm_read_overwrite(task, path, MAXPATHLEN, (mach_vm_address_t)rwpi.prp_vip.vip_path, &size3) != KERN_SUCCESS)
							strcpy(rwpi.prp_vip.vip_path, "<Unknown>");
					}
					if (!rwpi.prp_vip.vip_vi.vi_stat.vst_dev && !rwpi.prp_vip.vip_vi.vi_stat.vst_ino) {
						rwpi.prp_prinfo.pri_address = addr;
						rwpi.prp_prinfo.pri_size = 0;
					}
					sock = [PSSockModules psSockWithRwpi:&rwpi];
					if (sock) {
						while (rwpi.prp_prinfo.pri_size) {
							if (proc_pidinfo(socks.proc.pid, PROC_PIDREGIONPATHINFO, rwpi.prp_prinfo.pri_address + rwpi.prp_prinfo.pri_size,
								&rwpi, PROC_PIDREGIONPATHINFO_SIZE) != PROC_PIDREGIONPATHINFO_SIZE) break;
							if (rwpi.prp_vip.vip_vi.vi_stat.vst_dev && rwpi.prp_vip.vip_vi.vi_stat.vst_ino &&
								(rwpi.prp_vip.vip_vi.vi_stat.vst_dev != sock.dev || rwpi.prp_vip.vip_vi.vi_stat.vst_ino != sock.ino))
								break;
							if (!rwpi.prp_vip.vip_vi.vi_stat.vst_dev && !rwpi.prp_vip.vip_vi.vi_stat.vst_ino && rwpi.prp_prinfo.pri_user_tag)
								break;
							sock.size += rwpi.prp_prinfo.pri_size;
						}
						[socks.socks addObject:sock];
					}
				} else if (sock.display != ProcDisplayStarted)
					sock.display = ProcDisplayUser;
			}
			vm_deallocate(mach_task_self(), ii, iiSize);
		}
	}
	mach_port_deallocate(mach_task_self(), task);
	return 0;
}

@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//  PSSockArray

@implementation PSSockArray

- (instancetype)initSockArrayWithProc:(PSProc *)proc
{
	if (self = [super init]) {
		self.proc = proc;
		self.socks = [NSMutableArray arrayWithCapacity:300];
	}
	return self;
}

+ (instancetype)psSockArrayWithProc:(PSProc *)proc
{
	return [[PSSockArray alloc] initSockArrayWithProc:proc];
}

- (int)refreshWithMode:(column_mode_t)mode
{
	// Remove closed sockets
	[self.socks filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(PSSock *obj, NSDictionary *bind) {
		return obj.display != ProcDisplayTerminated;
	}]];
	[self setAllDisplayed:ProcDisplayTerminated];
	Class ModeClass[ColumnModes] = {[PSSockSummary class], [PSSockThreads class], [PSSockFiles class], [PSSockPorts class], [PSSockModules class]};
	return [ModeClass[mode] refreshArray:self];
}

- (void)sortUsingComparator:(NSComparator)comp desc:(BOOL)desc
{
	if (desc)
		[self.socks sortUsingComparator:^NSComparisonResult(id a, id b) { return comp(b, a); }];
	else
		[self.socks sortUsingComparator:comp];
}

- (void)setAllDisplayed:(display_t)display
{
	for (PSSock *sock in self.socks)
		// Setting all items to "normal" is used only to hide "started"
		if (display != ProcDisplayNormal || sock.display == ProcDisplayStarted)
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
	return (PSSock *)self.socks[idx];
}

- (PSSock *)objectPassingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate
{
	NSUInteger idx = [self.socks indexOfObjectPassingTest:predicate];
	return idx == NSNotFound ? nil : (PSSock *)self.socks[idx];
}

@end
