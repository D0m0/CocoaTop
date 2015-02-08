#import <mach/mach_types.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

@interface PSProc : NSObject
{
@public struct task_basic_info basic;
@public struct task_events_info events;
@public struct task_events_info events_prev;
}
typedef enum {
	ProcDisplaySystem,
	ProcDisplayUser,
	ProcDisplayNormal,
	ProcDisplayStarted,
	ProcDisplayTerminated,
	ProcDisplayRemove
} display_t;
@property (assign) display_t display;
@property (assign) pid_t pid;
@property (assign) pid_t ppid;
@property (assign) int prio;
@property (assign) int priobase;
@property (assign) int nice;
@property (assign) int flags;
@property (assign) int64_t ptime;	// 100's of a second
@property (assign) dev_t tdev;
@property (assign) uid_t uid;
@property (assign) gid_t gid;
#define PSPROC_STATES				"DZRUSITH?"
#define PSPROC_STATE_MAX			8
@property (assign) int state;
#define PSPROC_EXFLAGS_NICE			0x02		// 'v' p_nice > 0
#define PSPROC_EXFLAGS_NOTNICE		0x04		// '^' p_nice < 0
#define PSPROC_EXFLAGS_TRACED		0x08		// 't' P_TRACED (Debugged process being traced)
#define PSPROC_EXFLAGS_WEXIT		0x10		// 'z' P_WEXIT (Working on exiting)
#define PSPROC_EXFLAGS_PPWAIT		0x20		// 'w' P_PPWAIT (Parent waiting for chld exec/exit)
#define PSPROC_EXFLAGS_SYSPROC		0x40		// 'L' P_SYSTEM | P_NOSWAP | P_PHYSIO (Sys proc: no sigs, stats or swap)
//#define PSPROC_EXFLAGS_SWAPPED		0x01	// 's' TH_FLAGS_SWAPPED
//#define PSPROC_EXFLAGS_SLEADER		0x80	// 's' EPROC_SLEADER (Session leader)
//#define PSPROC_EXFLAGS_TERMINAL		0x100	// '+' P_CONTROLT (Controlling terminal)
@property (assign) int exflags;
@property (assign) int pcpu;
@property (assign) int threads;
@property (retain) NSString *name;
@property (retain) NSArray *args;
@property (retain) UIImage *icon;
@property (retain) NSDictionary *app;
- (instancetype)initWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size;
+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size;
- (void)updateWithKinfo:(struct kinfo_proc *)ki;
- (void)updateWithKinfoEx:(struct kinfo_proc *)ki;
+ (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki;

@end

@interface PSProcArray : NSObject
{
}
@property (retain) NSMutableArray *procs;
@property (assign) CGFloat iconSize;
+ (instancetype)psProcArrayWithIconSize:(CGFloat)size;
- (int)refresh;
- (void)sortWithComparator:(NSComparator)comp;
- (void)setAllDisplayed:(display_t)display;
- (NSUInteger)indexOfDisplayed:(display_t)display;
- (NSUInteger)count;
- (PSProc *)procAtIndex:(NSUInteger)index;

@end
