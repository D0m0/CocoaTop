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
@property (assign) int flags;
@property (retain) NSString *name;
@property (retain) NSArray *args;
- (instancetype)initWithKinfo:(struct kinfo_proc *)proc args:(NSArray *)args;
+ (instancetype)psprocWithKinfo:(struct kinfo_proc *)proc args:(NSArray *)args;

@end
