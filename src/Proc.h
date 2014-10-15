#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

@interface PSProc : NSObject
{
}
@property (assign) pid_t pid;
@property (assign) NSString *name;
- (instancetype)initWithPid:(pid_t)newpid name:(const char *)newname;

@end
