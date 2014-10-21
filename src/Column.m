#import "Column.h"

@implementation PSColumn

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width sort:(NSComparator *)sort
{
	if (self = [super init]) {
		self.name = name;
		self.descr = descr;
		self.align = align;
		self.width = width;
		self.sort = sort;
    }
	return self;
}

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width sort:(NSComparator *)sort
{
	return [[[PSColumn alloc] initWithName:name descr:descr align:align width:width sort:sort] autorelease];
}

- (void)dealloc
{
	[self.name release];
	[self.descr release];
	[super dealloc];
}

@end
