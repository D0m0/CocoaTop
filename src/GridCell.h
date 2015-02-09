#import <UIKit/UIKit.h>
#import "Proc.h"
#import "Column.h"

@interface GridTableCell : UITableViewCell
{
	CGFloat firstCol;
}
@property (retain) NSMutableArray *labels;
@property (retain) NSMutableArray *dividers;
+ (instancetype)cellWithId:(NSString *)reuseIdentifier proc:(PSProc *)proc columns:(NSArray *)columns size:(CGSize)size;
- (void)updateWithProc:(PSProc *)proc columns:(NSArray *)columns;

@end


@interface GridHeaderView : UITableViewHeaderFooterView
{
}
@property (retain) NSMutableArray *labels;
@property (retain) NSMutableArray *dividers;
+ (instancetype)headerWithColumns:(NSArray *)columns size:(CGSize)size;

@end
