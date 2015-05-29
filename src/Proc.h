#import <UIKit/UIKit.h>
#import <mach/mach_types.h>
#import "sys/resource.h"
#import <sys/sysctl.h>
#define PRIVATE
#import "net/ntstat.h"
#import "Compat.h"

// Display states determine grid row colors
typedef enum {
	ProcDisplaySystem,
	ProcDisplayUser,
	ProcDisplayNormal,
	ProcDisplayStarted,
	ProcDisplayTerminated,
	ProcDisplayRemove
} display_t;

// Thread states are sorted by priority, top priority becomes a "task state"
typedef enum {
	ProcStateDebugging,
	ProcStateZombie,
	ProcStateRunning,
	ProcStateUninterruptible,
	ProcStateSleeping,
	ProcStateIndefiniteSleep,
	ProcStateTerminated,
	ProcStateHalted,
	ProcStateMax
} proc_state_t;

#define PROC_STATE_CHARS "DZRUSITH?"

typedef struct PSCounts {
	pid_t				pid;
	nstat_provider_id_t	provider;
	nstat_src_ref_t		srcref;
	u_int64_t			rxpackets;
	u_int64_t			rxbytes;
	u_int64_t			txpackets;
	u_int64_t			txbytes;
} PSCounts;

@interface PSProc : NSObject
{
@public mach_task_basic_info_data_t basic;
@public struct task_events_info events;
@public struct task_events_info events_prev;
@public struct rusage_info_v2 rusage;
@public struct rusage_info_v2 rusage_prev;
@public struct PSCounts netstat;
@public struct PSCounts netstat_prev;
@public struct PSCounts netstat_cache;
}
@property (assign) display_t display;
@property (assign) pid_t pid;
@property (assign) pid_t ppid;
@property (assign) unsigned int prio;
@property (assign) unsigned int priobase;
@property (assign) task_role_t role;
@property (assign) int nice;
@property (assign) unsigned int flags;
@property (assign) unsigned int ptime;	// 100's of a second
@property (assign) dev_t tdev;
@property (assign) uid_t uid;
@property (assign) gid_t gid;
@property (assign) proc_state_t state;
@property (assign) unsigned int pcpu;
@property (assign) unsigned int threads;
@property (assign) unsigned int ports;
@property (assign) unsigned int files;
@property (retain) NSString *name;
@property (retain) NSString *executable;
@property (retain) NSString *args;
@property (retain) UIImage *icon;
@property (retain) NSDictionary *app;
@property (retain) NSMutableDictionary *dispQueue;
//@property (retain) NSMutableArray *cpuhistory;
+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size;
- (void)update;
- (void)updateWithKinfo:(struct kinfo_proc *)ki;
@end

proc_state_t mach_state_order(struct thread_basic_info *tbi);
unsigned int mach_thread_priority(thread_t thread, policy_t policy);
