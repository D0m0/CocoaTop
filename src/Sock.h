#import "Compat.h"
#import "Column.h"
#import "Proc.h"

#define KEV_ANY_VENDOR				0
#define KEV_ANY_CLASS				0
#define KEV_ANY_SUBCLASS			0

// All kernel event classes and subclasses. Thanks, Google!
#define KEV_VENDOR_APPLE			1
#define KEV_NETWORK_CLASS			1
#define		KEV_INET_SUBCLASS			1
#define		KEV_DL_SUBCLASS				2
#define		KEV_NETPOLICY_SUBCLASS		3
#define		KEV_SOCKET_SUBCLASS			4
#define		KEV_ATALK_SUBCLASS			5
#define		KEV_INET6_SUBCLASS			6
#define 	KEV_ND6_SUBCLASS 			7
#define 	KEV_NECP_SUBCLASS 			8
#define 	KEV_NETAGENT_SUBCLASS		9
#define		KEV_LOG_SUBCLASS			10
#define KEV_IOKIT_CLASS				2
#define KEV_SYSTEM_CLASS			3
#define		KEV_CTL_SUBCLASS			2
#define		KEV_MEMORYSTATUS_SUBCLASS	3
#define KEV_APPLESHARE_CLASS		4
#define KEV_FIREWALL_CLASS			5
#define		KEV_IPFW_SUBCLASS			1
#define		KEV_IP6FW_SUBCLASS			2
#define KEV_IEEE80211_CLASS			6
#define 	KEV_APPLE80211_EVENT_SUBCLASS	1

#define PIPE_ASYNC      0x004   /* Async? I/O. */
#define PIPE_WANTR      0x008   /* Reader wants some characters. */
#define PIPE_WANTW      0x010   /* Writer wants space to put characters. */
#define PIPE_WANT       0x020   /* Pipe is wanted to be run-down. */
#define PIPE_SEL        0x040   /* Pipe has a select active. */
#define PIPE_EOF        0x080   /* Pipe is in EOF condition. */
#define PIPE_LOCKFL     0x100   /* Process has exclusive access to pointers/data. */
#define PIPE_LWANT      0x200   /* Process wants exclusive access to pointers/data. */
#define PIPE_DIRECTW    0x400   /* Pipe direct write active. */
#define PIPE_DIRECTOK   0x800   /* Direct mode ok. */
#define PIPE_KNOTE      0x1000  /* Pipe has kernel events activated */
#define PIPE_DRAIN      0x2000  /* Waiting for I/O to drop for a close. Treated like EOF; only separate for easier debugging. */
#define PIPE_WSELECT    0x4000  /* Some thread has done an FWRITE select on the pipe */
#define PIPE_DEAD       0x8000  /* Pipe is dead and needs garbage collection */

@class PSSockArray;

@interface PSSock : NSObject
@property (assign) display_t display;
@property (strong) NSString *name;
@property (strong) UIColor *color;
@property (assign) uint64_t node;
+ (int)refreshArray:(PSSockArray *)socks;
- (NSString *)description;
@end

@interface PSSockSummary : PSSock
@property (strong) PSProc *proc;
@property (strong) PSColumn *col;
@end

@interface PSSockThreads : PSSock
{ @public struct thread_basic_info tbi; }
@property (assign) uint64_t tid;
@property (assign) uint64_t ptime;		// 0.01's of a second
@property (assign) unsigned int prio;
@end

@interface PSSockFiles : PSSock
@property (assign) int32_t fd;
@property (assign) uint32_t type;
@property (assign) uint32_t flags;
@property (assign) char *stype;
@end

@interface PSSockPorts : PSSock
@property (strong) NSMutableString *connect;
@property (assign) mach_port_name_t port;
@property (assign) mach_port_type_t type;
@property (assign) natural_t object;
@end

@interface PSSockModules : PSSock
@property (strong) NSString *bundle;
@property (assign) mach_vm_address_t addr;
@property (assign) size_t size;
@property (assign) uint32_t ref;
@property (assign) uint32_t dev;
@property (assign) uint32_t ino;
@end

@interface PSSockArray : NSObject
@property (strong) PSProc *proc;
@property (strong) NSMutableArray *socks;
@property (strong) NSMutableDictionary *objects;	// Kernel objects for communication between processes (ports, pipes, sockets)
+ (instancetype)psSockArrayWithProc:(PSProc *)proc;
- (int)refreshWithMode:(column_mode_t)mode;
- (void)sortUsingComparator:(NSComparator)comp desc:(BOOL)desc;
- (void)setAllDisplayed:(display_t)display;
- (NSUInteger)indexOfDisplayed:(display_t)display;
- (NSUInteger)count;
- (PSSock *)objectAtIndexedSubscript:(NSUInteger)idx;
- (PSSock *)objectPassingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate;
@end
