#import <UIKit/UIKit.h>
#import "Compat.h"
#import "Proc.h"
#import "Sock.h"

typedef NSString *(^PSColumnData)(id proc);

@interface PSColumn : NSObject
// Full column name (in settings)
@property (retain) NSString *descr;
// Short name (in header)
@property (retain) NSString *name;
// NSTextAlignmentLeft or NSTextAlignmentRight
@property (assign) NSTextAlignment align;
// Minimal column width
@property (assign) NSInteger width;
// Data displayer (based on PSProc/PSSock data)
@property (assign) PSColumnData getData;
// Summary displayer (based on PSProcArray data)
@property (assign) PSColumnData getSummary;
// Sort comparator
@property (assign) NSComparator sort;
// Default sort direction
@property (assign) BOOL sortDesc;
// Should use monotype font
@property (assign) BOOL monoFont;
// Label tag
@property (assign) int tag;

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align
	width:(NSInteger)width sortDesc:(BOOL)desc monoFont:(BOOL)mono data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary;
+ (NSArray *)psGetAllColumns;
+ (NSMutableArray *)psGetShownColumnsWithWidth:(NSUInteger *)width;
+ (NSArray *)psGetTaskColumns:(NSInteger)kind;
+ (NSArray *)psGetTaskColumnsWithWidth:(NSUInteger *)width kind:(NSInteger)kind;

@end
