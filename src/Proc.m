#import "Proc.h"

@implementation PSProc

- (instancetype)initWithKInfoProc:(struct kinfo_proc *)proc
{
	_pid = proc->kp_proc.p_pid;
	_ppid = proc->kp_eproc.e_ppid;
	_name = [NSString stringWithCString:proc->kp_proc.p_comm encoding:NSASCIIStringEncoding];
	//UTF8String:(const char *)newname];
	[_name retain];
	return self;
}

@end
