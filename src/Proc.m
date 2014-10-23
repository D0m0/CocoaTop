#import "Proc.h"

@implementation PSProc

- (instancetype)initWithKinfo:(struct kinfo_proc *)ki
{
	if (self = [super init]) {
		self.display = ProcDisplayStarted;
		self.pid = ki->kp_proc.p_pid;
		self.ppid = ki->kp_eproc.e_ppid;
		self.prio = ki->kp_proc.p_priority;
		self.flags = ki->kp_proc.p_flag;
		self.args = [PSProc getArgsByKinfo:ki];
		self.name = [[self.args objectAtIndex:0] lastPathComponent];
    }
	return self;
}

+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki
{
	return [[[PSProc alloc] initWithKinfo:ki] autorelease];
}

- (void)updateWithKinfo:(struct kinfo_proc *)ki
{
	self.display = ProcDisplayUser;
	self.prio = ki->kp_proc.p_priority;
	self.flags = ki->kp_proc.p_flag;
}

+ (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki
{
	NSArray		*args = nil;
	int			nargs, c = 0;
	static int	argmax = 0;
	char		*argsbuf, *sp, *ap, *cp;
	int			mib[3] = {CTL_KERN, KERN_PROCARGS2, ki->kp_proc.p_pid};
	size_t		size;

	if (!argmax) {
		int mib2[2] = {CTL_KERN, KERN_ARGMAX};
		size = sizeof(argmax);
		if (sysctl(mib2, 2, &argmax, &size, NULL, 0) < 0)
			argmax = 1024;
	}
	// Allocate process environment buffer
	argsbuf = (char *)malloc(argmax);
	if (argsbuf) {
		size = (size_t)argmax;
		if (sysctl(mib, 3, argsbuf, &size, NULL, 0) == 0) {
			// Skip args count
			nargs = *(int *)argsbuf;
			cp = argsbuf + sizeof(nargs);
			// Skip exec_path and trailing nulls
			for (; cp < &argsbuf[size]; cp++)
				if (!*cp) break;
			for (; cp < &argsbuf[size]; cp++)
				if (*cp) break;

			for (sp = cp; cp < &argsbuf[size] && c < nargs; cp++)
				if (*cp == '\0') c++;
			if (sp != cp) {
				args = [[[[NSString alloc] initWithBytes:sp length:(cp-sp)
					encoding:NSUTF8StringEncoding] autorelease]		// NSASCIIStringEncoding?
					componentsSeparatedByString:@"\0"];
			}
		}
		free(argsbuf);
	}
	if (args)
		return args;
	ki->kp_proc.p_comm[MAXCOMLEN] = 0;	// Just in case
	return [NSArray arrayWithObject:[NSString stringWithFormat:@"(%s)", ki->kp_proc.p_comm]];
}

- (void)dealloc
{
	[_name release];
	[_args release];
	[super dealloc];
}

@end

@implementation PSProcArray

- (instancetype)initProcArray
{
	if (self = [super init])
		self.procs = [NSMutableArray arrayWithCapacity:200];
	return self;
}

+ (instancetype)psProcArray
{
	return [[[PSProcArray alloc] initProcArray] autorelease];
}

- (int)refresh
{
	struct kinfo_proc *kp;
	int nentries;
	size_t bufSize;
	int i, err;
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};

	// Remove terminated processes
	[self.procs filterUsingPredicate:[NSPredicate predicateWithBlock: ^BOOL(PSProc *obj, NSDictionary *bind) {
		return obj.display != ProcDisplayTerminated;
	}]];
	[self setAllDisplayed:ProcDisplayTerminated];
	// Get buffer size
	if (sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0)
		return errno;
	kp = (struct kinfo_proc *)malloc(bufSize);
	// Get process list and update the procs array
	err = sysctl(mib, 4, kp, &bufSize, NULL, 0);
	if (!err) {
		nentries = bufSize / sizeof(struct kinfo_proc);
		for (i = 0; i < nentries; i++) {
			NSUInteger idx = [self.procs indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
				return ((PSProc *)obj).pid == kp[i].kp_proc.p_pid;
			}];
			if (idx == NSNotFound)
				[self.procs addObject:[PSProc psProcWithKinfo:&kp[i]]];
			else
				[[self.procs objectAtIndex:idx] updateWithKinfo:&kp[i]];
		}
	}
	free(kp);
	// Sort by pid
	[self.procs sortUsingComparator:^NSComparisonResult(PSProc *a, PSProc *b) {
		return a.pid - b.pid;
	}];
	return err;
}

- (void)setAllDisplayed:(display_t)display
{
	for (PSProc *proc in self.procs)
		proc.display = display;
}

- (NSUInteger)indexOfDisplayed:(display_t)display
{
	return [self.procs indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return ((PSProc *)obj).display == display;
	}];
}

- (NSUInteger)count
{
	return [self.procs count];
}

- (PSProc *)procAtIndex:(NSUInteger)index
{
	return (PSProc *)[self.procs objectAtIndex:index];
}

- (void)dealloc
{
	[_procs release];
	[super dealloc];
}

@end
