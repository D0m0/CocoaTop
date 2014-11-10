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
		[self updateWithKinfo2:ki];
//		@autoreleasepool {
//			self.icon = [PSProc getIconForApp:[self.args objectAtIndex:0] size:80];
//		}
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
/*
+ (UIImage *)roundCorneredImage:(UIImage *)orig size:(NSInteger)dim radius:(CGFloat)r
{
	CGSize size = (CGSize){dim, dim};
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[[UIBezierPath bezierPathWithRoundedRect:(CGRect){CGPointZero, size} cornerRadius:r] addClip];
	[orig drawInRect:(CGRect){CGPointZero, size}];
	UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

+ (UIImage *)getIconForApp:(NSString *)fullpath size:(NSInteger)dim
{
	NSArray *path = [fullpath pathComponents];
	if (path.count > 5
		&& ![(NSString *)[path objectAtIndex:1] compare:@"var"]
		&& ![(NSString *)[path objectAtIndex:2] compare:@"mobile"]
		&& ![(NSString *)[path objectAtIndex:3] compare:@"Applications"]
	) {
		NSString *icon = [NSString stringWithFormat:@"/var/mobile/Applications/%@/iTunesArtwork", [path objectAtIndex:4]];
		UIImage *image = [UIImage imageWithContentsOfFile:icon];
		if (image)
			return [PSProc roundCorneredImage:image size:dim radius:dim/5];
	}
	return nil;
}
*/
/*
int get_task_info (KINFO *ki) 
{
	kern_return_t	error;
	unsigned int	info_count = TASK_BASIC_INFO_COUNT;
	unsigned int	thread_info_count = THREAD_BASIC_INFO_COUNT;
	pid_t			pid;
	int				j, err = 0;

	ki->state = STATE_MAX;
	pid = KI_PROC(ki)->p_pid;
	if (task_for_pid(mach_task_self(), pid, &ki->task) != KERN_SUCCESS)
		return(1);
	info_count = TASK_BASIC_INFO_COUNT;
	error = task_info(ki->task, TASK_BASIC_INFO, (task_info_t)&ki->tasks_info, &info_count);
	if (error != KERN_SUCCESS) {
		ki->invalid_tinfo=1;
		return(1);
	}
	info_count = TASK_THREAD_TIMES_INFO_COUNT;
	error = task_info(ki->task, TASK_THREAD_TIMES_INFO, (task_info_t)&ki->times, &info_count);
	if (error != KERN_SUCCESS) {
		ki->invalid_tinfo=1;
		return(1);
	}
//	switch(ki->tasks_info.policy) {
//	... see tasks.c

	ki->invalid_tinfo=0;
	ki->cpu_usage=0;
	error = task_threads(ki->task, &ki->thread_list, &ki->thread_count);
	if (error != KERN_SUCCESS) {
		mach_port_deallocate(mach_task_self(),ki->task);
		return(1);
	}
	err=0;
	ki->swapped = 1;
	ki->thval = malloc(ki->thread_count * sizeof(struct thread_values));
	for (j = 0; j < ki->thread_count; j++) {
		int tstate;
		thread_info_count = THREAD_BASIC_INFO_COUNT;
		error = thread_info(ki->thread_list[j], THREAD_BASIC_INFO, (thread_info_t)&ki->thval[j].tb, &thread_info_count);
		if (error != KERN_SUCCESS)
			err=1;
		error = thread_schedinfo(ki, ki->thread_list[j], ki->thval[j].tb.policy, &ki->thval[j].schedinfo);
		if (error != KERN_SUCCESS)
			err=1;
		ki->cpu_usage += ki->thval[j].tb.cpu_usage;
		tstate = mach_state_order(ki->thval[j].tb.run_state, ki->thval[j].tb.sleep_time);
		if (tstate < ki->state)
			ki->state = tstate;
		if ((ki->thval[j].tb.flags & TH_FLAGS_SWAPPED ) == 0)
			ki->swapped = 0;
		mach_port_deallocate(mach_task_self(), ki->thread_list[j]);
	}
	ki->invalid_thinfo = err;
	// Deallocate the list of threads
	error = vm_deallocate(mach_task_self(), (vm_address_t)(ki->thread_list), sizeof(*ki->thread_list) * ki->thread_count);
	if (error != KERN_SUCCESS)
		...
	mach_port_deallocate(mach_task_self(),ki->task);
	return(0);
}
*/


- (void)dealloc
{
	[_name release];
	[_args release];
	[_icon release];
	[super dealloc];
}

@end

@implementation PSProcArray

- (instancetype)initProcArray
{
	if (self = [super init]) {
		self.procs = [NSMutableArray arrayWithCapacity:200];
		self.appIcons = [PSAppIcon psAppIconArray];
	}
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
			if (idx == NSNotFound) {
				PSProc *proc = [PSProc psProcWithKinfo:&kp[i]];
				proc.name = [PSAppIcon getIconFileFromArray:self.appIcons forApp:[proc.args objectAtIndex:0]];
//				proc.icon = [PSAppIcon getIconFromArray:self.appIcons forApp:[proc.args objectAtIndex:0] size:80];
				[self.procs addObject:proc];
			} else
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
	[_appIcons release];
	[super dealloc];
}

@end
