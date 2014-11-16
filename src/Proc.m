#import "Proc.h"
#import "AppIcon.h"
#import <mach/mach_init.h>
#import <mach/task_info.h>
#import <mach/thread_info.h>
#import <mach/mach_interface.h>
#import <mach/mach_port.h>

extern kern_return_t task_for_pid(task_port_t task, pid_t pid, task_port_t *target);
extern kern_return_t task_info(task_port_t task, unsigned int info_num, task_info_t info, unsigned int *info_count);

@implementation PSProc

- (instancetype)initWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size
{
	if (self = [super init]) {
		@autoreleasepool {
			self.display = ProcDisplayStarted;
			self.pid = ki->kp_proc.p_pid;
			self.ppid = ki->kp_eproc.e_ppid;
			self.prio = ki->kp_proc.p_priority;
			self.flags = ki->kp_proc.p_flag;
			self.args = [PSProc getArgsByKinfo:ki];
			NSString *executable = [self.args objectAtIndex:0];
			self.name = [executable lastPathComponent];
			NSString *path = [executable stringByDeletingLastPathComponent];
			self.app = [PSAppIcon getAppByPath:path];
			if (self.app) {
				NSString *bundle = [self.app valueForKey:@"CFBundleIdentifier"];
				if (bundle) {
					self.name = bundle;
					self.icon = [PSAppIcon getIconForApp:self.app bundle:bundle path:path size:size];
				}
			}
			[self updateWithKinfo2:ki];
//	self.name = [app valueForKey:@"CFBundleIdentifier"];
//	self.bundleName = [app valueForKey:@"CFBundleName"];
//	self.displayName = [app valueForKey:@"CFBundleDisplayName"];
		}
	}
	return self;
}

+ (instancetype)psProcWithKinfo:(struct kinfo_proc *)ki iconSize:(CGFloat)size
{
	return [[[PSProc alloc] initWithKinfo:ki iconSize:size] autorelease];
}

- (void)updateWithKinfo:(struct kinfo_proc *)ki
{
	self.display = ProcDisplayUser;
	self.prio = ki->kp_proc.p_priority;
	self.flags = ki->kp_proc.p_flag;
	[self updateWithKinfo2:ki];
}

- (void)updateWithKinfo2:(struct kinfo_proc *)ki
{
		task_port_t task;
		unsigned int info_count;
		self.threads = 0;
		if (task_for_pid(mach_task_self(), ki->kp_proc.p_pid, &task) == KERN_SUCCESS) {
			taskInfoValid = YES;
			info_count = TASK_BASIC_INFO_COUNT;
			if (task_info(task, TASK_BASIC_INFO, (task_info_t)&taskInfo, &info_count) != KERN_SUCCESS)
				taskInfoValid = NO;
			info_count = TASK_THREAD_TIMES_INFO_COUNT;
			if (task_info(task, TASK_THREAD_TIMES_INFO, (task_info_t)&times, &info_count) != KERN_SUCCESS)
				taskInfoValid = NO;

//			kern_return_t				error;
			unsigned int				thread_count;
			thread_port_array_t			thread_list;
			struct thread_basic_info	thval;

			self.pcpu = 0;
			if (task_threads(task, &thread_list, &thread_count) == KERN_SUCCESS) {
				self.threads = thread_count;
//				err=0;
//				ki->swapped = 1;
				for (unsigned int j = 0; j < thread_count; j++) {
					info_count = THREAD_BASIC_INFO_COUNT;
					if (thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)&thval, &info_count) == KERN_SUCCESS)
						self.pcpu += thval.cpu_usage;
//					int tstate = mach_state_order(thval.run_state, thval.sleep_time);
//					if (tstate < ki->state)
//						ki->state = tstate;
//					if ((thval.flags & TH_FLAGS_SWAPPED ) == 0)
//						ki->swapped = 0;
					mach_port_deallocate(mach_task_self(), thread_list[j]);
				}
//				ki->invalid_thinfo = err;
				// Deallocate the list of threads
				vm_deallocate(mach_task_self(), (vm_address_t)thread_list, sizeof(*thread_list) * thread_count);
			}
			mach_port_deallocate(mach_task_self(), task);
		} else
			taskInfoValid = NO;
}

+ (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki
{
	NSArray		*args = nil;
	int			nargs, c = 0;
	static int	argmax = 0;
	char		*argsbuf, *sp, *cp;
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
	[_icon release];
	[_app release];
	[super dealloc];
}

@end

@implementation PSProcArray

- (instancetype)initProcArrayWithIconSize:(CGFloat)size
{
	if (self = [super init]) {
		self.procs = [NSMutableArray arrayWithCapacity:200];
		self.iconSize = size;
	}
	return self;
}

+ (instancetype)psProcArrayWithIconSize:(CGFloat)size
{
	return [[[PSProcArray alloc] initProcArrayWithIconSize:size] autorelease];
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
				[self.procs addObject:[PSProc psProcWithKinfo:&kp[i] iconSize:self.iconSize]];
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
