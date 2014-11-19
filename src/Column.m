#import "Column.h"

@implementation PSColumn

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width refresh:(BOOL)refresh id:(int)cid sort:(NSComparator)sort
{
	if (self = [super init]) {
		self.name = name;
		self.descr = descr;
		self.align = align;
		self.width = width;
		self.sort = sort;
		self.refresh = refresh;
		self.cid = [NSNumber numberWithInt:cid];
    }
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width refresh:(BOOL)refresh id:(int)cid sort:(NSComparator)sort
{
	return [[PSColumn alloc] initWithName:name descr:descr align:align width:width refresh:refresh id:cid sort:sort];
}

+ (NSArray *)psAllColumnsArray
{
	return @[
		[PSColumn psColumnWithName:@"Command" descr:@"Command line" align:NSTextAlignmentLeft width:600 refresh:NO id:0
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }],
		[PSColumn psColumnWithName:@"PID" descr:@"Process ID" align:NSTextAlignmentRight width:50 refresh:NO id:1
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pid - b.pid; }],
		[PSColumn psColumnWithName:@"PPID" descr:@"Parent PID" align:NSTextAlignmentRight width:50 refresh:NO id:2
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ppid - b.ppid; }],
		[PSColumn psColumnWithName:@"Flags" descr:@"Process Flags" align:NSTextAlignmentLeft width:100 refresh:YES id:3
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.flags - b.flags; }],
		[PSColumn psColumnWithName:@"Prio" descr:@"Process Priority" align:NSTextAlignmentLeft width:50 refresh:YES id:4
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.prio - b.prio; }],
		[PSColumn psColumnWithName:@"VSize" descr:@"Virtual Size" align:NSTextAlignmentRight width:65 refresh:YES id:5
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->taskInfo.virtual_size - b->taskInfo.virtual_size; }],
		[PSColumn psColumnWithName:@"RSize" descr:@"Resident Size" align:NSTextAlignmentRight width:65 refresh:YES id:6
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->taskInfo.resident_size - b->taskInfo.resident_size; }],
		[PSColumn psColumnWithName:@"%CPU" descr:@"%CPU Usage" align:NSTextAlignmentRight width:50 refresh:YES id:7
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pcpu - b.pcpu; }],
		[PSColumn psColumnWithName:@"Threads" descr:@"Thread Count" align:NSTextAlignmentRight width:40 refresh:YES id:8
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.threads - b.threads; }]
// TIME Ports MRegions RPrivate RShared
	];
}

+ (NSArray *)psColumnsArray
{
	return @[
		[PSColumn psColumnWithName:@"Command" descr:@"Command line" align:NSTextAlignmentLeft width:600 refresh:NO id:0
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }],
		[PSColumn psColumnWithName:@"PID" descr:@"Process ID" align:NSTextAlignmentRight width:50 refresh:NO id:1
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pid - b.pid; }],
		[PSColumn psColumnWithName:@"PPID" descr:@"Parent PID" align:NSTextAlignmentRight width:50 refresh:NO id:2
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ppid - b.ppid; }],
		[PSColumn psColumnWithName:@"Flags" descr:@"Process Flags" align:NSTextAlignmentLeft width:100 refresh:YES id:3
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.flags - b.flags; }],
//		[PSColumn psColumnWithName:@"Prio" descr:@"Process Priority" align:NSTextAlignmentLeft width:50 refresh:YES id:4
//			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.prio - b.prio; }],
//		[PSColumn psColumnWithName:@"VSize" descr:@"Virtual Size" align:NSTextAlignmentRight width:65 refresh:YES id:5
//			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->taskInfo.virtual_size - b->taskInfo.virtual_size; }],
		[PSColumn psColumnWithName:@"RSize" descr:@"Resident Size" align:NSTextAlignmentRight width:65 refresh:YES id:6
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->taskInfo.resident_size - b->taskInfo.resident_size; }],
		[PSColumn psColumnWithName:@"%CPU" descr:@"%CPU Usage" align:NSTextAlignmentRight width:50 refresh:YES id:7
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pcpu - b.pcpu; }],
		[PSColumn psColumnWithName:@"Threads" descr:@"Thread Count" align:NSTextAlignmentRight width:40 refresh:YES id:8
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.threads - b.threads; }]
// TIME Ports MRegions RPrivate RShared
	];
}

/*
if (rawcpu) return p->p_pctcpu;

#define FSHIFT  11              // bits to right of fixed binary point
#define FSCALE  (1<<FSHIFT)
// decay 95% of `p_pctcpu' in 60 seconds; see CCPU_SHIFT before changing
fixpt_t ccpu = 0.95122942450071400909 * FSCALE;         // exp(-1/20)
return p->p_pctcpu / (1.0 - exp(p->p_swtime * log(fxtofl(ccpu))));

#define TH_USAGE_SCALE 1000
(void)printf("%*.1f", v->width, ((double)cp) * 100.0 / ((double)TH_USAGE_SCALE)); 
*/

- (NSString *)getDataForProc:(PSProc *)proc
{
	switch (self.cid.intValue) {
	case 0: return proc.name;
	case 1: return [NSString stringWithFormat:@"%u", proc.pid];
	case 2: return [NSString stringWithFormat:@"%u", proc.ppid];
	case 3: return [NSString stringWithFormat:@"%08X", proc.flags];
	case 4: return [NSString stringWithFormat:@"%u", proc.prio];
	case 5: return !proc->taskInfoValid ? @"-" :
		[NSByteCountFormatter stringFromByteCount:proc->taskInfo.virtual_size countStyle:NSByteCountFormatterCountStyleMemory];
	case 6: return !proc->taskInfoValid ? @"-" :
		[NSByteCountFormatter stringFromByteCount:proc->taskInfo.resident_size countStyle:NSByteCountFormatterCountStyleMemory];
	case 7: return [NSString stringWithFormat:@"%.1f", (float)proc.pcpu/10];
	case 8: return [NSString stringWithFormat:@"%u", proc.threads];
	default: return @"N/A";
	}
}

- (void)dealloc
{
	[_name release];
	[_descr release];
	[super dealloc];
}

@end
