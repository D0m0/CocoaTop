#import "Sock.h"
#import <mach-o/dyld_images.h>
#import <mach/thread_info.h>
#import <arpa/inet.h>
#import <netdb.h>
#import "proc_info.h"
#import "libproc.h"

@implementation PSSock

- (instancetype)initWithPid:(pid_t)pid fd:(int32_t)fd type:(uint32_t)type
{
	NSString *name = nil, *stype = nil;
	UIColor *color = [UIColor blackColor];
	uint32_t flags = 0;

	if (type == PROX_FDTYPE_VNODE) {
		struct vnode_fdinfowithpath info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDVNODEPATHINFO, &info, PROC_PIDFDVNODEPATHINFO_SIZE) != PROC_PIDFDVNODEPATHINFO_SIZE)
			return nil;
		name = [NSString stringWithCString:info.pvip.vip_path encoding:NSUTF8StringEncoding];
		name = [PSSymLink simplifyPathName:name];
		stype = @"VNODE";
		flags = info.pfi.fi_openflags;
	} else if (type == PROX_FDTYPE_PIPE) {
		struct pipe_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDPIPEINFO, &info, PROC_PIDFDPIPEINFO_SIZE) != PROC_PIDFDPIPEINFO_SIZE)
			return nil;
		name = [NSString stringWithFormat:@"%llX -> %llX", info.pipeinfo.pipe_handle, info.pipeinfo.pipe_peerhandle];
		if (info.pipeinfo.pipe_status & PIPE_WANTR)		name = [name stringByAppendingString:@" READ"];
		if (info.pipeinfo.pipe_status & PIPE_WANTW)		name = [name stringByAppendingString:@" WRITE"];
		if (info.pipeinfo.pipe_status & PIPE_SEL)		name = [name stringByAppendingString:@" SELECT"];
		if (info.pipeinfo.pipe_status & PIPE_EOF)		name = [name stringByAppendingString:@" EOF"];
		if (info.pipeinfo.pipe_status & PIPE_KNOTE)		name = [name stringByAppendingString:@" KNOTE"];
		if (info.pipeinfo.pipe_status & PIPE_DRAIN)		name = [name stringByAppendingString:@" DRAIN"];
		if (info.pipeinfo.pipe_status & PIPE_DEAD)		name = [name stringByAppendingString:@" DEAD"];
		stype = @"PIPE";
		color = [UIColor blueColor];
		flags = info.pfi.fi_openflags;
	} else if (type == PROX_FDTYPE_KQUEUE) {
		struct kqueue_fdinfo info;
		if (proc_pidfdinfo(pid, fd, PROC_PIDFDKQUEUEINFO, &info, PROC_PIDFDKQUEUEINFO_SIZE) != PROC_PIDFDKQUEUEINFO_SIZE)
			return nil;
		name = [NSString stringWithFormat:@"KQUEUE: %@", info.kqueueinfo.kq_state == PROC_KQUEUE_SELECT ? @"SELECT" : info.kqueueinfo.kq_state == PROC_KQUEUE_SLEEP ? @"SLEEP" : @"SUSPENDED"];
		stype = @"QUEUE";
		color = [UIColor brownColor];
		flags = info.pfi.fi_openflags;
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
			name = [NSString stringWithFormat:@"KEXT: %s", info.psi.soi_proto.pri_kern_ctl.kcsi_name];
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
		flags = info.pfi.fi_openflags;
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
		self.flags = flags;
	}
	return self;
}

+ (instancetype)psSockWithPid:(pid_t)pid fd:(int32_t)fd type:(uint32_t)type
{
	return [[[PSSock alloc] initWithPid:pid fd:fd type:type] autorelease];
}

- (instancetype)initWithRwpi:(struct proc_regionwithpathinfo *)rwpi
{
	if (!rwpi->prp_vip.vip_path[0] && !rwpi->prp_vip.vip_vi.vi_stat.vst_dev && !rwpi->prp_vip.vip_vi.vi_stat.vst_ino)
		return nil;
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.name = rwpi->prp_vip.vip_path[0] ? [PSSymLink simplifyPathName:[NSString stringWithCString:rwpi->prp_vip.vip_path encoding:NSUTF8StringEncoding]] : @"<none>";
		self.addr = rwpi->prp_prinfo.pri_address;
		self.addrend = rwpi->prp_prinfo.pri_address + rwpi->prp_prinfo.pri_size;
		self.dev = rwpi->prp_vip.vip_vi.vi_stat.vst_dev;
		self.ino = rwpi->prp_vip.vip_vi.vi_stat.vst_ino;
		self.stype = @"IMG";
		self.color = self.dev && self.ino ? [UIColor blackColor] : [UIColor grayColor];
	}
	return self;
}

+ (instancetype)psSockWithRwpi:(struct proc_regionwithpathinfo *)rwpi
{
	return [[[PSSock alloc] initWithRwpi:rwpi] autorelease];
}

- (instancetype)initWithId:(uint64_t)tid tbi:(struct thread_basic_info *)tbi
{
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.name = [NSString stringWithFormat:@"TID: %llX", tid];
		self.addr = tid;
		self.pcpu = tbi->cpu_usage;
		self.policy = tbi->policy;
		self.color = [UIColor blackColor];
	}
	return self;
}

+ (instancetype)psSockWithId:(uint64_t)tid tbi:(struct thread_basic_info *)tbi
{
	return [[[PSSock alloc] initWithId:tid tbi:tbi] autorelease];
}

- (instancetype)initWithProc:(PSProc *)proc column:(PSColumn *)col
{
	if (self = [super init]) {
		self.display = ProcDisplayNormal;
		self.proc = proc;
		self.col = col;
		self.name = col.descr;
	}
	return self;
}

+ (instancetype)psSockWithProc:(PSProc *)proc column:(PSColumn *)col
{
	return [[[PSSock alloc] initWithProc:proc column:col] autorelease];
}

- (void)dealloc
{
	[_name release];
	[_stype release];
	[_color release];
	[_proc release];
	[_col release];
	[super dealloc];
}

@end

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
	return [[[PSSockArray alloc] initSockArrayWithProc:proc] autorelease];
}


struct dyld_image_info64 {
	mach_vm_address_t			imageLoadAddress;	/* base address image is mapped into */
	mach_vm_address_t			imageFilePath;		/* path dyld used to load the image */
	mach_vm_size_t				imageFileModDate;	/* time_t of image file */
													/* if stat().st_mtime of imageFilePath does not match imageFileModDate, */
													/* then file has been modified since dyld loaded it */
};

struct dyld_all_image_infos64 {
	uint32_t						version;
	uint32_t						infoArrayCount;
	mach_vm_address_t				infoArray;					// struct dyld_image_info64*
	dyld_image_notifier				notification;		
	bool							processDetachedFromSharedRegion;
	bool							libSystemInitialized;
	mach_vm_address_t				dyldImageLoadAddress;
	mach_vm_address_t				jitInfo;
	mach_vm_address_t				dyldVersion;				// char*
	mach_vm_address_t				errorMessage;				// char*
	uint64_t						terminationFlags;
	mach_vm_address_t				coreSymbolicationShmPage;
	uint64_t						systemOrderFlag;
	uint64_t						uuidArrayCount;
	mach_vm_address_t				uuidArray;					// struct dyld_uuid_info*
	mach_vm_address_t				dyldAllImageInfosAddress;	// struct dyld_all_image_infos64*
	uint64_t						initialImageCount;
	uint64_t						errorKind;
	mach_vm_address_t				errorClientOfDylibPath;		// char*
	mach_vm_address_t				errorTargetDylibPath;		// char*
	mach_vm_address_t				errorSymbol;				// char*
	uint64_t						sharedCacheSlide;
};

- (int)refreshWithMode:(column_mode_t)mode
{
	// Remove closed sockets
	[self.socks filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(PSSock *obj, NSDictionary *bind) {
		return obj.display != ProcDisplayTerminated;
	}]];
	[self setAllDisplayed:ProcDisplayTerminated];
	if (mode == ColumnModeSummary) {
		[self.socks removeAllObjects];
		for (PSColumn *col in [PSColumn psGetAllColumns]) {
			PSSock *sock = [PSSock psSockWithProc:self.proc column:col];
			if (sock) [self.socks addObject:sock];
		}
	} else if (mode == ColumnModeFiles) {
		// Get buffer size
		int bufSize = proc_pidinfo(self.proc.pid, PROC_PIDLISTFDS, 0, 0, 0);
		if (bufSize <= 0)
			return EPERM;
		// Make sure the buffer is large enough ;)
		bufSize *= 2;
		struct proc_fdinfo *fdinfo = (struct proc_fdinfo *)malloc(bufSize);
		if (!fdinfo)
			return ENOMEM;
		// Get socket list and update the socks array
		bufSize = proc_pidinfo(self.proc.pid, PROC_PIDLISTFDS, 0, fdinfo, bufSize);
		if (bufSize > 0) {
			for (int i = 0; i < bufSize / PROC_PIDLISTFD_SIZE; i++) {
// This is bad: fds are often reused, so we wouldn't notice if it changed (at least we check the fdtype...)
				PSSock *sock = [self sockForFd:fdinfo[i].proc_fd type:fdinfo[i].proc_fdtype];
				if (!sock) {
					sock = [PSSock psSockWithPid:self.proc.pid fd:fdinfo[i].proc_fd type:fdinfo[i].proc_fdtype];
					if (sock) [self.socks addObject:sock];
				} else if (sock.display != ProcDisplayStarted)
					sock.display = ProcDisplayUser;
			}
		}
		free(fdinfo);
	} else if (mode == ColumnModeThreads) {
		task_port_t task;
		if (task_for_pid(mach_task_self(), self.proc.pid, &task) == KERN_SUCCESS) {
			thread_port_array_t thread_list;
			unsigned int thread_count;
			if (task_threads(task, &thread_list, &thread_count) == KERN_SUCCESS) {
				for (unsigned int j = 0; j < thread_count; j++) {
					struct thread_identifier_info tii = {0};
					struct thread_basic_info tbi = {{0}};
					unsigned int info_count = THREAD_IDENTIFIER_INFO_COUNT;
					thread_info(thread_list[j], THREAD_IDENTIFIER_INFO, (thread_info_t)&tii, &info_count);
					info_count = THREAD_BASIC_INFO_COUNT;
					thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)&tbi, &info_count);
					if (tii.thread_id) {
						PSSock *sock = [self sockForAddr:tii.thread_id];
						if (!sock) {
							sock = [PSSock psSockWithId:tii.thread_id tbi:&tbi];
							if (sock) [self.socks addObject:sock];
						} else if (sock.display != ProcDisplayStarted) {
							sock.display = ProcDisplayUser;
							sock.pcpu = tbi.cpu_usage;
							sock.policy = tbi.policy;
						}
					}
					mach_port_deallocate(mach_task_self(), thread_list[j]);
				}
				vm_deallocate(mach_task_self(), (vm_address_t)thread_list, sizeof(*thread_list) * thread_count);
			}
			mach_port_deallocate(mach_task_self(), task);
		}
	} else if (mode == ColumnModeModules) {
		// Avoid resetting device...
		if (self.proc.pid == 0)
			return EPERM;
		task_port_t task;
		if (task_for_pid(mach_task_self(), self.proc.pid, &task) == KERN_SUCCESS) {
			task_dyld_info_data_t task_dyld_info;
			mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
			if (task_info(task, TASK_DYLD_INFO, (task_info_t)&task_dyld_info, &count) == KERN_SUCCESS) {
				struct dyld_all_image_infos64 aii;
				mach_vm_size_t aiiSize = sizeof(aii);
				if (mach_vm_read_overwrite(task, task_dyld_info.all_image_info_addr, aiiSize, (mach_vm_address_t)&aii, &aiiSize) == KERN_SUCCESS) {
					mach_vm_address_t		ii;
					uint32_t				iiCount;
					mach_msg_type_number_t	iiSize;
					if (self.proc.flags & P_LP64) {
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
							if (self.proc.flags & P_LP64) {
								struct dyld_image_info64 *ii64 = (struct dyld_image_info64 *)ii;
								addr = ii64[i].imageLoadAddress;
								path = ii64[i].imageFilePath;
							} else {
								struct dyld_image_info *ii32 = (struct dyld_image_info *)ii;
								addr = (mach_vm_address_t)ii32[i].imageLoadAddress;
								path = (mach_vm_address_t)ii32[i].imageFilePath;
							}
							struct proc_regionwithpathinfo rwpi;
							if (proc_pidinfo(self.proc.pid, PROC_PIDREGIONPATHINFO, addr, &rwpi, PROC_PIDREGIONPATHINFO_SIZE) != PROC_PIDREGIONPATHINFO_SIZE)
								continue;
							PSSock *sock = [self sockForAddr:addr];
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
								sock = [PSSock psSockWithRwpi:&rwpi];
								if (sock) {
									//while (rwpi.prp_prinfo.pri_size) {
									//	addr = rwpi.prp_prinfo.pri_address + rwpi.prp_prinfo.pri_size;
									//	if (proc_pidinfo(self.proc.pid, PROC_PIDREGIONPATHINFO, addr, &rwpi, PROC_PIDREGIONPATHINFO_SIZE) != PROC_PIDREGIONPATHINFO_SIZE) break;
									//	if (rwpi.prp_vip.vip_vi.vi_stat.vst_dev != sock.dev || rwpi.prp_vip.vip_vi.vi_stat.vst_ino != sock.ino)
									//		break;
									//	sock.addrend = rwpi.prp_prinfo.pri_address + rwpi.prp_prinfo.pri_size;
									//}
									[self.socks addObject:sock];
								}
							} else if (sock.display != ProcDisplayStarted)
								sock.display = ProcDisplayUser;
						}
						vm_deallocate(mach_task_self(), ii, iiSize);
					}
				}
			}
			mach_port_deallocate(mach_task_self(), task);
		}
	}
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

- (PSSock *)sockForFd:(int32_t)fd type:(uint32_t)type
{
	NSUInteger idx = [self.socks indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return ((PSSock *)obj).fd == fd && ((PSSock *)obj).type == type;
	}];
	return idx == NSNotFound ? nil : (PSSock *)self.socks[idx];
}

- (PSSock *)sockForAddr:(mach_vm_address_t)addr
{
	NSUInteger idx = [self.socks indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return ((PSSock *)obj).addr == addr;
	}];
	return idx == NSNotFound ? nil : (PSSock *)self.socks[idx];
}

- (void)dealloc
{
	[_socks release];
	[super dealloc];
}

@end
