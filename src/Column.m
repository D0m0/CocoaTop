#import "Column.h"

@implementation PSColumn

+ (NSArray *)psGetAllColumns
{
	static NSArray *allColumns;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		allColumns = [@[
		[PSColumn psColumnWithName:@"Command line" descr:@"Command line" align:NSTextAlignmentLeft width:600 refresh:NO
			data:^NSString*(PSProc *proc) { return proc.name; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }],
		[PSColumn psColumnWithName:@"PID" descr:@"Process ID" align:NSTextAlignmentRight width:50 refresh:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.pid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pid - b.pid; }],
		[PSColumn psColumnWithName:@"PPID" descr:@"Parent PID" align:NSTextAlignmentRight width:50 refresh:NO
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.ppid]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ppid - b.ppid; }],
		[PSColumn psColumnWithName:@"Flags" descr:@"Process Flags" align:NSTextAlignmentLeft width:100 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%08X", proc.flags]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.flags - b.flags; }],
		[PSColumn psColumnWithName:@"Prio" descr:@"Process Priority" align:NSTextAlignmentLeft width:50 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.prio]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.prio - b.prio; }],
		[PSColumn psColumnWithName:@"VMem" descr:@"Virtual Size" align:NSTextAlignmentRight width:65 refresh:YES
			data:^NSString*(PSProc *proc) { return !proc->taskInfoValid ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->taskInfo.virtual_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->taskInfo.virtual_size - b->taskInfo.virtual_size; }],
		[PSColumn psColumnWithName:@"RMem" descr:@"Resident Size" align:NSTextAlignmentRight width:65 refresh:YES
			data:^NSString*(PSProc *proc) { return !proc->taskInfoValid ? @"-" :
				[NSByteCountFormatter stringFromByteCount:proc->taskInfo.resident_size countStyle:NSByteCountFormatterCountStyleMemory]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a->taskInfo.resident_size - b->taskInfo.resident_size; }],
		[PSColumn psColumnWithName:@"%" descr:@"%CPU Usage" align:NSTextAlignmentRight width:50 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%.1f", (float)proc.pcpu/10]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pcpu - b.pcpu; }],
		[PSColumn psColumnWithName:@"Thr" descr:@"Thread Count" align:NSTextAlignmentRight width:40 refresh:YES
			data:^NSString*(PSProc *proc) { return [NSString stringWithFormat:@"%u", proc.threads]; }
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.threads - b.threads; }]
		// TIME Ports MRegions RPrivate RShared
		] retain];
	});
	return allColumns;
}

+ (NSMutableArray *)psGetShownColumns
{
	NSArray *columnOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Columns"];
	NSArray *cols = [PSColumn psGetAllColumns];
	NSMutableArray *shownCols = [NSMutableArray array];
	NSUInteger ccc = cols.count;

	for (NSNumber* order in columnOrder)
		if (order.unsignedIntegerValue < ccc)
			[shownCols addObject:cols[order.intValue]];
	return shownCols;
}

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width refresh:(BOOL)refresh data:(PSColumnData)data sort:(NSComparator)sort
{
	if (self = [super init]) {
		self.name = name;
		self.descr = descr;
		self.align = align;
		self.width = width;
		self.getData = data;
		self.sort = sort;
		self.refresh = refresh;
    }
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width refresh:(BOOL)refresh data:(PSColumnData)data sort:(NSComparator)sort
{
	return [[PSColumn alloc] initWithName:name descr:descr align:align width:width refresh:refresh data:data sort:sort];
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
/*	switch ([AllColumns indexOfObject:self]) {
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
	}*/
	return @"N/A";
}

- (void)dealloc
{
	[_name release];
	[_descr release];
	[super dealloc];
}

@end
