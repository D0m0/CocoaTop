#import <UIKit/UIKit.h>
#import "Proc.h"
#import "Sock.h"

typedef NSString *(^PSColumnData)(id proc);

@interface PSColumn : NSObject
// Full column name (in settings)
@property (retain) NSString *descr;
// Short name (in header)
@property (retain) NSString *name;
// UITextAlignmentLeft or UITextAlignmentRight
@property (assign) UITextAlignment align;
// Minimal column width
@property (assign) NSInteger width;
// Data displayer (based on PSProc/PSSock data)
@property (assign) PSColumnData getData;
// Summary displayer (based on PSProcArray data)
@property (assign) PSColumnData getSummary;
// Sort comparator
@property (assign) NSComparator sort;
// Need to refresh
@property (assign) BOOL refresh;
// Label tag
@property (assign) int tag;

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(UITextAlignment)align
	width:(NSInteger)width refresh:(BOOL)refresh data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary;
+ (NSArray *)psGetAllColumns;
+ (NSMutableArray *)psGetShownColumnsWithWidth:(NSUInteger *)width;
+ (NSArray *)psGetOpenFilesColumnsWithWidth:(NSUInteger *)width;

@end
