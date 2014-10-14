#import <UIKit/UIKit.h>

@interface GridTableCell : UITableViewCell
{
	NSMutableArray *columns;
}
- (void)addColumn:(CGFloat)position;

@end

