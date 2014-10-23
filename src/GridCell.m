#import "GridCell.h"
#import "Proc.h"
#import "Column.h"

@implementation GridTableCell

CGFloat firstCol;

- (instancetype)initWithId:(NSString *)reuseIdentifier proc:(PSProc *)proc columns:(NSArray *)columns height:(CGFloat)height
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
	firstCol = ((PSColumn *)[columns objectAtIndex:0]).width;
	CGFloat totalCol = firstCol;

	self.labels = [[NSMutableArray arrayWithCapacity:columns.count-1] retain];
	self.dividers = [[NSMutableArray arrayWithCapacity:columns.count-1] retain];
	for (int i = 1; i < columns.count; i++) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(totalCol, 0, 1, height)];
		[self.dividers addObject:divider];
		//[divider release];
		divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
		[cell.contentView addSubview:divider];

		PSColumn *col = [columns objectAtIndex:i];
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 10, 0, col.width - 11, height)];
		[self.labels addObject:label];
		//[label release];
		label.font = [UIFont systemFontOfSize:12.0];
		label.text = [col getDataForProc:proc];
		label.backgroundColor = [UIColor clearColor];
//		label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
		[cell.contentView addSubview:label];
		totalCol += col.width;
	}
	return cell;
}

+ (instancetype)cellWithId:(NSString *)reuseIdentifier proc:(PSProc *)proc columns:(NSArray *)columns height:(CGFloat)height
{
	return [[[GridTableCell alloc] initWithId:reuseIdentifier proc:proc columns:columns height:height] autorelease];
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
	[self.labels release];
	[self.dividers release];
	[super dealloc];
}

@end
