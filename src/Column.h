#import <UIKit/UIKit.h>

typedef enum {
	ColumnModeSummary = 0,
	ColumnModeThreads,
	ColumnModeFiles,
	ColumnModePorts,
	ColumnModeModules,
	ColumnModes
} column_mode_t;

typedef enum {
	ColumnStyleExtend = 1,		// This column will take up all remaining unused space
	ColumnStyleEllipsis = 2,	// Trim data with ellipsis instead of shrinking font
	ColumnStyleForSummary = 4,	// Column is shown only in process summary
	ColumnStyleMonoFont = 8,	// Use mono font (used to display memory addresses)
	ColumnStyleTooLong = 16,	// Use a shorter text for cell (but not summary)
	ColumnStyleNoSummary = 32,	// Column is not shown in process summary
	ColumnStyleSortDesc = 64,	// Default sorting is "high to low"
	ColumnStylePath = 128,		// This column should be truncated path-like
	ColumnStylePathTrunc = 131,	// ColumnStylePath + ColumnStyleExtend + ColumnStyleEllipsis
	ColumnStyleColor = 256,		// Column label can change color
	ColumnStyleLowSpace = 512,	// Column will not be shown in low-space environments (i.e. iPhone portrait mode)
} column_style_t;

typedef NSString *(^PSColumnData)(id proc);
typedef UIColor *(^PSColumnColor)(id proc);

@interface PSColumn : NSObject
// Full column name (in settings)
@property (strong) NSString *fullname;
// Short name (in header)
@property (strong) NSString *name;
// Multiline description (in settings column info)
@property (strong) NSString *descr;
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
// Color changer
@property (assign) PSColumnColor getColor;
// Sort comparator
@property (assign) NSComparator sort;
// Column styles bitmask
@property (assign) column_style_t style;
// Label tag
@property (assign) int tag;

+ (instancetype)psColumnWithName:(NSString *)name fullname:(NSString *)fullname align:(NSTextAlignment)align
	width:(NSInteger)width tag:(NSInteger)tag style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary color:(PSColumnColor)color descr:(NSString *)descr;
+ (instancetype)psColumnWithName:(NSString *)name fullname:(NSString *)fullname align:(NSTextAlignment)align
	width:(NSInteger)width tag:(NSInteger)tag style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary descr:(NSString *)descr;
+ (instancetype)psColumnWithName:(NSString *)name fullname:(NSString *)fullname align:(NSTextAlignment)align
	width:(NSInteger)width tag:(NSInteger)tag style:(column_style_t)style data:(PSColumnData)data sort:(NSComparator)sort summary:(PSColumnData)summary;
+ (NSArray *)psGetAllColumns;
+ (NSMutableArray *)psGetShownColumnsWithWidth:(NSUInteger)width;
+ (NSArray *)psGetTaskColumns:(column_mode_t)mode;
+ (NSArray *)psGetTaskColumnsWithWidth:(NSUInteger)width mode:(column_mode_t)mode;
+ (PSColumn *)psColumnWithTag:(NSInteger)tag;
+ (PSColumn *)psTaskColumnWithTag:(NSInteger)tag forMode:(column_mode_t)mode;

@end
