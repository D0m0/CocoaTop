#import "Proc.h"

@implementation PSProc

- (instancetype)initWithPid:(pid_t)newpid name:(const char *)newname;
{
	_pid = newpid;
	_name = [NSString stringWithUTF8String:(const char *)newname];
	return self;
}

@end
