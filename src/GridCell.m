#import "GridCell.h"

@implementation GridTableCell

- (void)addColumn:(CGFloat)position
{
	[columns addObject:[NSNumber numberWithFloat:position]];
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetRGBStrokeColor(ctx, 1.0, .5, .5, 1.0);
	CGContextSetLineWidth(ctx, 1.0);

	for (int i = 0; i < 2; i++) {
		CGFloat f = 100.0 * i;
		CGContextMoveToPoint(ctx, f, 0);
		CGContextAddLineToPoint(ctx, f, 30.0);
	}
/*	for (int i = 0; i < [columns count]; i++) {
		CGFloat f = [((NSNumber*) [columns objectAtIndex:i]) floatValue];
		CGContextMoveToPoint(ctx, f, 0);
		CGContextAddLineToPoint(ctx, f, rect.size.height);//self.bounds.size.height);
	}
*/
	CGContextStrokePath(ctx);

	[super drawRect:rect];
}

@end

