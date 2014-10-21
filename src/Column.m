#import "Column.h"

@implementation PSColumn

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width id:(int)cid sort:(NSComparator)sort
{
	if (self = [super init]) {
		self.name = name;
		self.descr = descr;
		self.align = align;
		self.width = width;
		self.sort = sort;
		self.cid = cid;
    }
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width id:(int)cid sort:(NSComparator)sort
{
	return [[[PSColumn alloc] initWithName:name descr:descr align:align width:width id:cid sort:sort] autorelease];
}

+ (NSArray *)psColumnsArray
{
	return [[NSArray arrayWithObjects:
		[PSColumn psColumnWithName:@"Command" descr:@"Command line" align:NSTextAlignmentLeft width:600 id:0
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return [a.name caseInsensitiveCompare:b.name]; }],
		[PSColumn psColumnWithName:@"PID" descr:@"Process ID" align:NSTextAlignmentLeft width:60 id:1
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.pid - b.pid; }],
		[PSColumn psColumnWithName:@"PPID" descr:@"Parent PID" align:NSTextAlignmentLeft width:60 id:2
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.ppid - b.ppid; }],
		[PSColumn psColumnWithName:@"Flags" descr:@"Process Flags" align:NSTextAlignmentLeft width:100 id:3
			sort:^NSComparisonResult(PSProc *a, PSProc *b) { return a.flags - b.flags; }],
// %CPU TIME Threads Ports MRegions RPrivate RShared RSize VSize
	nil] autorelease];
}

- (NSString *)getDataForProc:(PSProc *)proc
{
	switch (self.cid) {
	case 0: return proc.name;
	case 1: return [NSString stringWithFormat:@"%u", proc.pid];
	case 2: return [NSString stringWithFormat:@"%u", proc.ppid];
	case 3: return [NSString stringWithFormat:@"%08X", proc.flags];
	default: return @"N/A";
	}
}

- (void)dealloc
{
	[self.name release];
	[self.descr release];
	[super dealloc];
}

@end
