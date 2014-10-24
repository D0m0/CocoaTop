#import "GridCell.h"
#import "Proc.h"
#import "Column.h"

@implementation GridTableCell

CGFloat firstCol;

- (instancetype)initWithId:(NSString *)reuseIdentifier proc:(PSProc *)proc columns:(NSArray *)columns size:(CGSize)size
{
	GridTableCell *cell = (GridTableCell *)[super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];

	cell.textLabel.text = proc.name;
	NSString *full = [[[proc.args objectAtIndex:0] copy] autorelease];
	for (int i = 1; i < proc.args.count; i++)
		full = [full stringByAppendingFormat:@" %@", [proc.args objectAtIndex:i]];
	cell.detailTextLabel.text = full;
//	cell.detailTextLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
//	cell.accessoryType = indexPath.row < 5 ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryNone;
	cell.indentationLevel = proc.ppid <= 1 ? 0 : 1;

	// Remember first column width
	firstCol = MIN(((PSColumn *)[columns objectAtIndex:0]).width, size.width);
	CGFloat totalCol = firstCol;

	self.labels = [[NSMutableArray arrayWithCapacity:columns.count-1] retain];
	self.dividers = [[NSMutableArray arrayWithCapacity:columns.count-1] retain];
	for (int i = 1; i < columns.count /*&& totalCol < size.width*/; i++) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(totalCol, 0, 1, size.height)];
		[self.dividers addObject:divider];
		//[divider release];
		divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
		[cell.contentView addSubview:divider];

		PSColumn *col = [columns objectAtIndex:i];
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 4, 0, col.width - 8, size.height)];
		[self.labels addObject:label];
		label.textAlignment = col.align;
		label.font = [UIFont systemFontOfSize:12.0];
		label.text = [col getDataForProc:proc];
		label.backgroundColor = [UIColor clearColor];
//		label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
		[cell.contentView addSubview:label];
		totalCol += col.width;
	}
	return cell;
}

+ (instancetype)cellWithId:(NSString *)reuseIdentifier proc:(PSProc *)proc columns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridTableCell alloc] initWithId:reuseIdentifier proc:proc columns:columns size:size] autorelease];
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
	frame.size.width = firstCol - 10;
	self.detailTextLabel.frame = frame;
}

- (void)dealloc
{
	[_labels release];
	[_dividers release];
	[super dealloc];
}

@end
