#import "GridCell.h"
#import "Proc.h"
#import "Column.h"

@implementation GridTableCell

+ (NSString *)reuseIdWithIcon:(bool)withicon
{
	return withicon ? @"GridTableIconCell" : @"GridTableCell";
}

- (instancetype)initWithIcon:(bool)withicon
{
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[GridTableCell reuseIdWithIcon:withicon]];
	self.accessoryView = [[UIView new] autorelease];
	self.id = 0;
	return self;
}

+ (instancetype)cellWithIcon:(bool)withicon
{
	return [[[GridTableCell alloc] initWithIcon:withicon] autorelease];
}

- (void)configureWithId:(int)id columns:(NSArray *)columns size:(CGSize)size
{
	// Configuration did not change
	if (self.id == id)
		return;
	// Remove old views
	if (self.labels)
		for (UILabel *item in self.labels) [item removeFromSuperview];
	if (self.dividers)
		for (UIView *item in self.dividers) [item removeFromSuperview];
	// Create new views
	self.firstColWidth = size.width - 5;
	NSUInteger totalCol = self.firstColWidth;
	self.labels = [NSMutableArray arrayWithCapacity:columns.count-1];
	self.dividers = [NSMutableArray arrayWithCapacity:columns.count];
	self.extendArgsLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"FullWidthCommandLine"];
	if (size.height < 40)
		self.textLabel.font = [UIFont systemFontOfSize:12.0];
	else if (self.extendArgsLabel)
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
		label.adjustsFontSizeToFitWidth = YES;
		label.backgroundColor = [UIColor clearColor];
		label.tag = col.tag;
		[self.contentView addSubview:label];
		[label release];

		totalCol += col.width;
	}
	if (self.extendArgsLabel) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(self.firstColWidth, size.height, totalCol - self.firstColWidth, 1)];
		[self.dividers addObject:divider];
		divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
		[self.contentView addSubview:divider];
		[divider release];
	}
	self.id = id;
}

- (void)updateWithProc:(PSProc *)proc columns:(NSArray *)columns
{
	self.textLabel.text = proc.name;
	self.detailTextLabel.text = [proc.executable stringByAppendingString:proc.args];
	if (proc.icon)
		[self.imageView initWithImage:proc.icon];
	for (PSColumn *col in columns)
		if (col.tag > 1)
			((UILabel *)[self viewWithTag:col.tag]).text = col.getData(proc);
}

- (void)updateWithSock:(PSSock *)sock columns:(NSArray *)columns
{
	self.textLabel.text = sock.name;
	self.textLabel.textColor = sock.color;
	for (PSColumn *col in columns)
		if (col.tag > 1) {
			UILabel *label = (UILabel *)[self viewWithTag:col.tag];
			label.text = col.getData(sock);
			label.textColor = sock.color;
		}
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
	frame = self.imageView.frame;
		frame.origin.x = 0;
		self.imageView.frame = frame;
	frame = self.textLabel.frame;
		frame.origin.x = imageWidth;
		if (frame.origin.x) frame.origin.x += 5;
		frame.size.width = self.firstColWidth - imageWidth - 5;
		self.textLabel.frame = frame;
	frame = self.detailTextLabel.frame;
		frame.origin.x = imageWidth;
		if (frame.origin.x) frame.origin.x += 5;
		if (!self.extendArgsLabel) frame.size.width = self.firstColWidth - imageWidth - 5;
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

- (instancetype)initWithColumns:(NSArray *)columns size:(CGSize)size footer:(bool)footer
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
	self = [super initWithReuseIdentifier:@"Header"];
	self.backgroundView = ({
		UIView *view = [[UIView alloc] initWithFrame:self.bounds];
		view.backgroundColor = [UIColor colorWithRed:.75 green:.75 blue:.75 alpha:.85];
		view;
	});
#elif __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
	self = [super initWithReuseIdentifier:@"Header"];
#else
	self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
	self.backgroundColor = [UIColor colorWithRed:.75 green:.75 blue:.75 alpha:.85];
#endif
	NSUInteger totalCol = 0;
	self.labels = [[NSMutableArray arrayWithCapacity:columns.count] retain];
	self.dividers = [[NSMutableArray arrayWithCapacity:columns.count] retain];
	for (PSColumn *col in columns) {
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 2, 0, (col.tag > 1 ? col.width : size.width) - 4, size.height)];
		[self.labels addObject:label];
		[label release];
		label.textAlignment = footer && col.getSummary ? col.align : NSTextAlignmentCenter;
		label.font = footer && col.tag != 1 ? [UIFont systemFontOfSize:12.0] : [UIFont boldSystemFontOfSize:16.0];
		label.adjustsFontSizeToFitWidth = YES;
		label.text = footer ? @"-" : col.name;
		label.textColor = [UIColor blackColor];
		label.backgroundColor = [UIColor clearColor];
		label.tag = col.tag;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
		[self.contentView addSubview:label];
#else
		[self addSubview:label];
#endif
		totalCol += col.tag == 1 ? size.width : col.width;
	}
	return self;
}

+ (instancetype)headerWithColumns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridHeaderView alloc] initWithColumns:columns size:size footer:NO] autorelease];
}

+ (instancetype)footerWithColumns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridHeaderView alloc] initWithColumns:columns size:size footer:YES] autorelease];
}

- (void)sortColumnOld:(PSColumn *)oldCol New:(PSColumn *)newCol desc:(BOOL)desc
{
	UILabel *label;
	if (oldCol && oldCol != newCol)
	if ((label = (UILabel *)[self viewWithTag:oldCol.tag])) {
		label.textColor = [UIColor blackColor];
		label.text = oldCol.name;
	}
	if ((label = (UILabel *)[self viewWithTag:newCol.tag])) {
		label.textColor = [UIColor whiteColor];
		label.text = [newCol.name stringByAppendingString:(desc ? @"\u25BC" : @"\u25B2")];
	}
}

- (void)updateSummaryWithColumns:(NSArray *)columns procs:(PSProcArray *)procs
{
	for (PSColumn *col in columns)
		if (col.getSummary)
			((UILabel *)[self viewWithTag:col.tag]).text = col.getSummary(procs);
}

- (void)dealloc
{
	[_labels release];
	[_dividers release];
	[super dealloc];
}

@end
