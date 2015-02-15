#import <UIKit/UIKit.h>
#import "Proc.h"
#import "Column.h"

@interface GridTableCell : UITableViewCell
{
	BOOL extendArgsLabel;
	NSUInteger firstColWidth;
}
@property (retain) NSMutableArray *labels;
@property (retain) NSMutableArray *dividers;
+ (instancetype)cellWithId:(NSString *)reuseIdentifier columns:(NSArray *)columns size:(CGSize)size;
- (void)updateWithProc:(PSProc *)proc columns:(NSArray *)columns;

@end


@interface GridHeaderView : UITableViewHeaderFooterView
@property (retain) NSMutableArray *labels;
@property (retain) NSMutableArray *dividers;
+ (instancetype)headerWithColumns:(NSArray *)columns size:(CGSize)size;
- (void)sortColumnOld:(PSColumn *)oldCol New:(PSColumn *)newCol desc:(BOOL)desc;

@end
