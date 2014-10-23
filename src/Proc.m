#import "Proc.h"

@implementation PSProc

- (instancetype)initWithKinfo:(struct kinfo_proc *)proc args:(NSArray *)args
{
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.pid = proc->kp_proc.p_pid;
		self.ppid = proc->kp_eproc.e_ppid;
		self.prio = proc->kp_proc.p_priority;
		self.flags = proc->kp_proc.p_flag;
		self.args = args;
		self.name = [[args objectAtIndex:0] lastPathComponent];
    }
	return self;
}

- (void)updateWithKinfo:(struct kinfo_proc *)proc
{
	self.display = ProcDisplayUser;
	self.prio = proc->kp_proc.p_priority;
	self.flags = proc->kp_proc.p_flag;
}

+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)proc args:(NSArray *)args
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
