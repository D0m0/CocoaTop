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
@property (assign) unsigned int ptime;	// 100's of a second
@property (assign) dev_t tdev;
@property (assign) uid_t uid;
@property (assign) gid_t gid;
@property (assign) int state;
@property (assign) int pcpu;
@property (assign) int threads;
@property (assign) int ports;
@property (retain) NSString *name;
@property (retain) NSArray *args;
@property (retain) UIImage *icon;
@property (retain) NSDictionary *app;
+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size;
- (void)updateWithKinfo:(struct kinfo_proc *)ki;

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
