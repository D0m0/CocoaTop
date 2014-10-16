#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

@interface PSProc : NSObject
{
}
@property (assign) pid_t pid;
@property (assign) pid_t ppid;
@property (strong) NSString *name;
- (instancetype)initWithKInfoProc:(struct kinfo_proc *)proc;

@end
