#import <UIKit/UIKit.h>
#import "Compat.h"

typedef enum {
	ColumnModeSummary = 0,
	ColumnModeFiles,
	ColumnModeModules,
	ColumnModes
} column_mode_t;

#define ColumnNextMode(m) (((m) + 1) % ColumnModes)

typedef enum {
	ColumnStyleExtend = 1,
	ColumnStyleEllipsis = 2,
	ColumnStyleForSummary = 4,
	ColumnStyleMonoFont = 8,
	ColumnStyleTooLong = 16,
} column_style_t;

typedef NSString *(^PSColumnData)(id proc);

@interface PSColumn : NSObject
// Full column name (in settings)
@property (retain) NSString *descr;
// Short name (in header)
@property (retain) NSString *name;
// NSTextAlignmentLeft or NSTextAlignmentRight
@property (assign) NSTextAlignment align;
// Minimal column width
@property (assign) NSInteger minwidth;
// Current column width
@property (assign) NSInteger width;
// Data displayer (based on PSProc/PSSock data)
@property (assign) PSColumnData getData;
// Summary displayer (based on PSProcArray data)
@property (assign) PSColumnData getSummary;
// Sort comparator
@property (assign) NSComparator sort;
// Default sort direction
@property (assign) BOOL sortDesc;
// Column styles bitmask
@property (assign) column_style_t style;
// Label tag
@property (assign) int tag;

+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align
	width:(NSInteger)width sortDesc:(BOOL)desc style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary;
+ (NSArray *)psGetAllColumns;
+ (NSMutableArray *)psGetShownColumnsWithWidth:(NSUInteger)width;
+ (NSArray *)psGetTaskColumns:(column_mode_t)mode;
+ (NSArray *)psGetTaskColumnsWithWidth:(NSUInteger)width mode:(column_mode_t)mode;

@end
