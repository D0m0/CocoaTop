#import "GridCell.h"

@implementation GridTableCell

- (instancetype)initWithHeight:(CGFloat)height Id:(NSString *)reuseIdentifier
{
	GridTableCell *cell = (GridTableCell *)[super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
//	cell.detailTextLabel.text = @"Detailed description of command line parameters";
//	cell.detailTextLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;

	CGFloat col = 890;
	UIView *divider = [[[UIView alloc] initWithFrame:CGRectMake(col+10, 0, 1, height)] autorelease];
	divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
	[cell.contentView addSubview:divider];

	return cell;
}

- (void)addColumn:(CGFloat)position
{
	[columns addObject:[NSNumber numberWithFloat:position]];
}

//- (void)drawRect:(CGRect)rect
//{
//	[super drawRect:rect];
//
//	CGContextRef ctx = UIGraphicsGetCurrentContext();
//	CGContextSetRGBStrokeColor(ctx, 1.0, .5, .5, 1.0);
//	CGContextSetLineWidth(ctx, 1.0);
//
//	for (int i = 0; i < [columns count]; i++) {
//		CGFloat f = [((NSNumber*) [columns objectAtIndex:i]) floatValue];
//		CGContextMoveToPoint(ctx, f, 0);
//		CGContextAddLineToPoint(ctx, f, self.bounds.size.height);
//	}
//	CGContextStrokePath(ctx);
//}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect frame = self.detailTextLabel.frame;
	frame.size.width = 880;
	self.detailTextLabel.frame = frame;
}

@end
