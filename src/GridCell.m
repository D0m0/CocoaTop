#import "GridCell.h"
#import "Proc.h"
#import "Column.h"

@implementation GridTableCell

- (instancetype)initWithId:(NSString *)reuseIdentifier columns:(NSArray *)columns size:(CGSize)size
{
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
//	self.detailTextLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
//	self.accessoryType = indexPath.row < 5 ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryNone;
	// Calculate first column width
	firstColWidth = size.width - 5;
	CGFloat totalCol = firstColWidth;
	// Get other columns
	self.labels = [[NSMutableArray arrayWithCapacity:columns.count-1] retain];
	self.dividers = [[NSMutableArray arrayWithCapacity:columns.count] retain];
	extendArgsLabel = YES;//firstColWidth < ((PSColumn *)columns[0]).width;
	if (extendArgsLabel)
		size.height /= 2;
	for (PSColumn *col in columns) if (col.tag > 1) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(totalCol, 0, 1, size.height)];
		[self.dividers addObject:divider];
		divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
		[self.contentView addSubview:divider];
		[divider release];

		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 4, 0, col.width - 8, size.height)];
		[self.labels addObject:label];
		label.textAlignment = col.align;
		label.font = [UIFont systemFontOfSize:12.0];
		label.backgroundColor = [UIColor clearColor];
		label.tag = col.tag;
		[self.contentView addSubview:label];
		[label release];
		totalCol += col.width;
	}
	if (extendArgsLabel) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(firstColWidth, size.height, totalCol - firstColWidth, 1)];
		[self.dividers addObject:divider];
		divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
		[self.contentView addSubview:divider];
		[divider release];
	}
	return self;
}

+ (instancetype)cellWithId:(NSString *)reuseIdentifier columns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridTableCell alloc] initWithId:reuseIdentifier columns:columns size:size] autorelease];
}

- (void)updateWithProc:(PSProc *)proc columns:(NSArray *)columns
{
	self.textLabel.text = proc.name;
	NSString *full = [[proc.args[0] copy] autorelease];
	for (int i = 1; i < proc.args.count; i++)
		full = [full stringByAppendingFormat:@" %@", proc.args[i]];
	self.detailTextLabel.text = full;
//	self.indentationLevel = proc.ppid <= 1 ? 0 : 1;
	// Get application icon
	if (proc.icon)
		[self.imageView initWithImage:proc.icon];
	// Fill data
	for (PSColumn *col in columns)
		if (col.tag > 1)
			((UILabel *)[self viewWithTag:col.tag]).text = col.getData(proc);
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGRect frame;
	NSInteger imageWidth = self.imageView.frame.size.width;
	frame = self.contentView.frame;
		frame.origin.x = 5;
		frame.size.width -= 10;
		self.contentView.frame = frame;
	frame = self.textLabel.frame;
		frame.origin.x = imageWidth;
		if (frame.origin.x) frame.origin.x += 5;
		frame.size.width = firstColWidth - imageWidth - 5;
		self.textLabel.frame = frame;
	frame = self.detailTextLabel.frame;
		frame.origin.x = imageWidth;
		if (frame.origin.x) frame.origin.x += 5;
		if (!extendArgsLabel) frame.size.width = firstColWidth - imageWidth - 5;
			else frame.size.width = self.contentView.frame.size.width - imageWidth;
		self.detailTextLabel.frame = frame;
}

- (void)dealloc
{
	[_labels release];
	[_dividers release];
	[super dealloc];
}

@end


@implementation GridHeaderView

- (instancetype)initWithColumns:(NSArray *)columns size:(CGSize)size
{
	self = [super initWithReuseIdentifier:@"Header"];
	// Get column widths
	CGFloat totalCol = 0;
	self.labels = [[NSMutableArray arrayWithCapacity:columns.count] retain];
	self.dividers = [[NSMutableArray arrayWithCapacity:columns.count] retain];
	for (PSColumn *col in columns) {
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 2, 0, (col.tag > 1 ? col.width : size.width) - 4, size.height)];
		[self.labels addObject:label];
		[label release];
		label.textAlignment = NSTextAlignmentCenter;//col.align;
		label.font = [UIFont boldSystemFontOfSize:16.0];
		label.adjustsFontSizeToFitWidth = YES;
		label.text = col.name;
		label.textColor = [UIColor blackColor];
		label.backgroundColor = [UIColor clearColor];
		label.tag = col.tag;
		[self.contentView addSubview:label];
		totalCol += col.tag == 1 ? size.width : col.width;
	}
	return self;
}

+ (instancetype)headerWithColumns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridHeaderView alloc] initWithColumns:columns size:size] autorelease];
}

- (void)dealloc
{
	[_labels release];
	[_dividers release];
	[super dealloc];
}

@end
