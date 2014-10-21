#import <UIKit/UIKit.h>

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
// Sort comparator
//@property (nonatomic, copy) returnType (^blockName)(parameterTypes);
@property (assign) NSComparator *sort;

- (instancetype)initWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width sort:(NSComparator *)sort;
+ (instancetype)psColumnWithName:(NSString *)name descr:(NSString *)descr align:(NSTextAlignment)align width:(NSInteger)width sort:(NSComparator *)sort;

@end
