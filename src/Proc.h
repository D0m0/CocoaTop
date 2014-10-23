#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

@interface PSProc : NSObject
{
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
@property (retain) NSString *name;
@property (retain) NSArray *args;
- (instancetype)initWithKinfo:(struct kinfo_proc *)ki;
+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki;
- (void)updateWithKinfo:(struct kinfo_proc *)ki;
+ (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki;

@end

@interface PSProcArray : NSObject
{
}
@property (retain) NSMutableArray *procs;
+ (instancetype)psProcArray;
- (int)refresh;
- (void)setAllDisplayed:(display_t)display;
- (NSUInteger)indexOfDisplayed:(display_t)display;
- (NSUInteger)count;
- (PSProc *)procAtIndex:(NSUInteger)index;

@end
