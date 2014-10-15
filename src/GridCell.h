#import <UIKit/UIKit.h>

@interface GridTableCell : UITableViewCell
{
	NSMutableArray *columns;
}
- (instancetype)initWithHeight:(CGFloat)height Id:(NSString *)reuseIdentifier;
- (void)addColumn:(CGFloat)position;
//- (void)drawRect:(CGRect)rect;
- (void)layoutSubviews;

@end
