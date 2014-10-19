#import "Proc.h"

@implementation PSProc

- (instancetype)initWithKinfo:(struct kinfo_proc *)proc args:(NSArray *)args
{
	if (self = [super init]) {
		self.display = ProcDisplayNormal;
		self.pid = proc->kp_proc.p_pid;
		self.ppid = proc->kp_eproc.e_ppid;
		self.flags = proc->kp_proc.p_flag;
//		self.name = [NSString stringWithCString:proc->kp_proc.p_comm encoding:NSASCIIStringEncoding];
		self.args = args;
		self.name = [[args objectAtIndex:0] lastPathComponent];
    }
	return self;
}

+ (instancetype)psprocWithKinfo:(struct kinfo_proc *)proc args:(NSArray *)args
{
	return [[[PSProc alloc] initWithKinfo:proc args:args] autorelease];
}

- (void)dealloc
{
	[self.name release];
	[self.args release];
	[super dealloc];
}

@end
