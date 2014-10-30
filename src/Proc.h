#import <mach/mach_types.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

@interface PSProc : NSObject
{
@public BOOL taskInfoValid;
@public struct task_basic_info taskInfo;
@public struct task_thread_times_info times;
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
@property (assign) int flags;
@property (assign) int pcpu;
@property (assign) int threads;
@property (retain) NSString *name;
@property (retain) NSArray *args;
@property (retain) UIImage *icon;
- (instancetype)initWithKinfo:(struct kinfo_proc *)ki;
+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki;
- (void)updateWithKinfo:(struct kinfo_proc *)ki;
- (void)updateWithKinfo2:(struct kinfo_proc *)ki;
+ (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki;
//+ (UIImage *)getIconForApp:(NSString *)fullpath size:(NSInteger)dim;

@end

@interface PSProcArray : NSObject
{
}
@property (retain) NSMutableArray *procs;
@property (retain) NSArray *appIcons;
+ (instancetype)psProcArray;
- (int)refresh;
- (void)setAllDisplayed:(display_t)display;
- (NSUInteger)indexOfDisplayed:(display_t)display;
- (NSUInteger)count;
- (PSProc *)procAtIndex:(NSUInteger)index;

@end
