#import <UIKit/UIKit.h>
#import "Proc.h"

typedef NSString *(^PSColumnData)(PSProc *proc);

@interface PSColumn : NSObject
{
}
// Full column name (in settings)
@property (retain) NSString *descr;
// Short name (in header)
@property (retain) NSString *name;
// NSTextAlignmentLeft or NSTextAlignmentRight
@property (assign) NSTextAlignment align;
// Minimal column width
@property (assign) NSInteger width;
// Data displayer
@property (assign) PSColumnData getData;
// Sort comparator
@property (assign) NSComparator sort;
// Need to refresh
@property (assign) BOOL refresh;
// Label tag
@property (assign) int tag;

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align
	width:(NSInteger)width refresh:(BOOL)refresh data:(PSColumnData)data sort:(NSComparator)sort;
+ (NSArray *)psGetAllColumns;
+ (NSMutableArray *)psGetShownColumns;

@end
