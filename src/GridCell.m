#import <objc/runtime.h>
#import "Compat.h"
#import "GridCell.h"

/*
@interface SmallGraph : UIView
@property (strong) NSArray *dots;
@end

@implementation SmallGraph

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	self.backgroundColor = [UIColor whiteColor]; // clear
	return self;
}

+ (id)graphWithFrame:(CGRect)frame
{
	return [[SmallGraph alloc] initWithFrame:frame];
}

//void draw1PxStroke(CGContextRef context, CGPoint startPoint, CGPoint endPoint, CGColorRef color)
//{
//	CGContextSaveGState(context);
//	CGContextSetLineCap(context, kCGLineCapSquare);
//	CGContextSetLineWidth(context, 1.0);
//	CGContextSetStrokeColorWithColor(context, color);
//	CGContextMoveToPoint(context, startPoint.x + 0.5, startPoint.y + 0.5);
//	CGContextAddLineToPoint(context, endPoint.x + 0.5, endPoint.y + 0.5);
//	CGContextStrokePath(context);
//	CGContextRestoreGState(context);
//}

- (void)drawRect:(CGRect)rect
{
	if (!self.dots) return;
	CGContextRef context = UIGraphicsGetCurrentContext();
	UIColor *color = [UIColor colorWithRed:0.7 green:0.7 blue:1.0 alpha:1.0];
	CGFloat width = self.bounds.size.width,
			height = self.bounds.size.height;
	CGPoint bot = CGPointMake(self.bounds.origin.x + 0.5, self.bounds.origin.y + height + 0.5);

	CGContextSaveGState(context);
	CGContextSetLineCap(context, kCGLineCapSquare);
	CGContextSetLineWidth(context, 1.0);
	CGContextSetStrokeColorWithColor(context, color.CGColor);
	for (NSNumber *val in self.dots) {
//		draw1PxStroke(context, bot, CGPointMake(bot.x, bot.y - (height * [val unsignedIntegerValue] / 100)), color.CGColor);
		CGContextMoveToPoint(context, bot.x, bot.y);
		CGContextAddLineToPoint(context, bot.x, bot.y - (height * [val unsignedIntegerValue] / 200));
		CGContextStrokePath(context);
		bot.x++;
		if (bot.x >= width) break;
	}
	CGContextRestoreGState(context);
}

@end
*/



@implementation GridTableCell

+ (NSString *)reuseIdWithIcon:(bool)withicon
{
	return withicon ? @"GridTableIconCell" : @"GridTableCell";
}

- (instancetype)initWithIcon:(bool)withicon
{
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:[GridTableCell reuseIdWithIcon:withicon]];
	self.accessoryView = [UIView new];
	self.id = 0;
	return self;
}

+ (instancetype)cellWithIcon:(bool)withicon
{
	return [[GridTableCell alloc] initWithIcon:withicon];
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
	self.labels = [NSMutableArray arrayWithCapacity:columns.count-1];
	self.dividers = [NSMutableArray arrayWithCapacity:columns.count];
	self.extendArgsLabel = [[NSUserDefaults standardUserDefaults] boolForKey:@"FullWidthCommandLine"];
	self.colorDiffs = [[NSUserDefaults standardUserDefaults] boolForKey:@"ColorDiffs"];
	self.textLabel.font = size.height > 40 ? [UIFont systemFontOfSize:18.0] : [UIFont systemFontOfSize:12.0];
	if (size.height > 40 && self.extendArgsLabel)
		size.height /= 2;
	NSUInteger totalCol;
	for (PSColumn *col in columns)
		if (col == columns[0]) {
			self.firstColWidth = totalCol = col.width - 5;
			self.textLabel.adjustsFontSizeToFitWidth = !(col.style & ColumnStyleEllipsis);
			if (col.style & ColumnStylePath) {
				if (!(col.style & ColumnStyleTooLong)) self.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
				self.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
			}
		} else {
			UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(totalCol, 0, 1, size.height)];
            if (@available(iOS 13, *)) {
                divider.backgroundColor = UIColor.secondarySystemBackgroundColor;
            } else {
                divider.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
            }
			[self.dividers addObject:divider];
			[self.contentView addSubview:divider];

			//if (col.tag == 4) {
			//	SmallGraph *graph = [SmallGraph graphWithFrame:CGRectMake(totalCol + 1, 0, col.width - 1, size.height)];
			//	graph.tag = 1000;//col.tag;
			//	[self.labels addObject:graph];
			//	[self.contentView addSubview:graph];
			//}
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 4, 0, col.width - 8, size.height)];
			label.textAlignment = col.align;
			label.font = col.style & ColumnStyleMonoFont ? [UIFont fontWithName:@"Courier" size:13.0] : [UIFont systemFontOfSize:12.0];
			label.adjustsFontSizeToFitWidth = !(col.style & ColumnStyleEllipsis);
			if (col.style & ColumnStylePath) label.lineBreakMode = NSLineBreakByTruncatingMiddle;
			label.backgroundColor = [UIColor clearColor];
			label.tag = col.tag + 1;
			[self.labels addObject:label];
			[self.contentView addSubview:label];

			totalCol += col.width;
		}
	if (self.extendArgsLabel) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(self.firstColWidth, size.height, totalCol - self.firstColWidth, 1)];
		[self.dividers addObject:divider];
		if (@available(iOS 13, *)) {
            divider.backgroundColor = UIColor.secondarySystemBackgroundColor;
        } else {
            divider.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
        }
		[self.contentView addSubview:divider];
	}
	self.id = id;
}

- (void)updateWithProc:(PSProc *)proc columns:(NSArray *)columns
{
	self.textLabel.text = proc.name;
	self.detailTextLabel.text = [proc.executable stringByAppendingString:proc.args];
	if (proc.icon)
		self.imageView.image = proc.icon;
	for (PSColumn *col in columns)
		if (col != columns[0]) {
			//if (col.tag == 4) {
			//	SmallGraph *graph = (SmallGraph *)[self viewWithTag:1000];//col.tag];
			//	if (graph) { graph.dots = [proc.cpuhistory copy]; [graph setNeedsDisplay]; }
			//} //else {
			UILabel *label = (UILabel *)[self viewWithTag:col.tag + 1];
			if (label) {
				label.text = col.getData(proc);
				if (self.colorDiffs && (col.style & ColumnStyleColor))
					label.textColor = col.getColor(proc);
			}
		}
}

- (void)updateWithSock:(PSSock *)sock columns:(NSArray *)columns
{
	self.detailTextLabel.textColor = [UIColor grayColor];
	for (PSColumn *col in columns) {
		UILabel *label;
		if (col != columns[0])
			label = (UILabel *)[self viewWithTag:col.tag + 1];
		else if (col.style & ColumnStyleTooLong) {
			self.textLabel.text = sock.description;
			label = self.detailTextLabel;
		} else {
			self.detailTextLabel.text = nil;
			label = self.textLabel;
		}
		if (label) {
			// The cell label gets a shorter text (sock.name), but the summary page will get the full one
			label.text = col.style & ColumnStyleTooLong ? sock.name : col.getData(sock);
			if (col != columns[0])
			label.textColor = sock.color;
		}
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

@end


@implementation GridHeaderView

- (instancetype)initWithColumns:(NSArray *)columns size:(CGSize)size footer:(bool)footer
{
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (@available(iOS 7, *)) {
        self = [super initWithReuseIdentifier:@"Header"];
        self.backgroundView = ({
            UIView *view = [[UIView alloc] initWithFrame:self.bounds];
            if (@available(iOS 13, *)) {
                view.backgroundColor = [UIColor colorWithDynamicProvider:^(UITraitCollection *collection) {
                    if (collection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                        return [UIColor colorWithWhite:.31 alpha:.85];
                    } else {
                        return [UIColor colorWithWhite:.75 alpha:.85];
                    }
                }];
            } else {
                view.backgroundColor = [UIColor colorWithWhite:.75 alpha:.85];
            }
            view;
        });
    } else {
        self = [super initWithReuseIdentifier:@"Header"];
    }
//#elif __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
//	self = [super initWithReuseIdentifier:@"Header"];
//#else
//	self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
//	self.backgroundColor = [UIColor colorWithWhite:.75 alpha:.85];
//#endif
	self.labels = [NSMutableArray arrayWithCapacity:columns.count];
	self.dividers = [NSMutableArray arrayWithCapacity:columns.count];
	NSUInteger totalCol = 0;
	for (PSColumn *col in columns) {
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 2, 0, col.width - 4, size.height)];
		[self.labels addObject:label];
		label.textAlignment = footer && col.getSummary ? col.align : NSTextAlignmentCenter;
		label.font = footer && col != columns[0] ? [UIFont systemFontOfSize:12.0] : [UIFont boldSystemFontOfSize:16.0];
		label.adjustsFontSizeToFitWidth = YES;
		label.text = footer ? @"-" : col.name;
        if (@available(iOS 13, *)) {
            label.textColor = [UIColor labelColor];
        } else {
            label.textColor = [UIColor blackColor];
        }
		label.backgroundColor = [UIColor clearColor];
		label.tag = col.tag + 1;
//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
        if (@available(iOS 6, *)) {
            [self.contentView addSubview:label];
        } else {
//#else
            [self addSubview:label];
        }
//#endif
		totalCol += col.width;
	}
	return self;
}

+ (instancetype)headerWithColumns:(NSArray *)columns size:(CGSize)size
{
	return [[GridHeaderView alloc] initWithColumns:columns size:size footer:NO];
}

+ (instancetype)footerWithColumns:(NSArray *)columns size:(CGSize)size
{
	return [[GridHeaderView alloc] initWithColumns:columns size:size footer:YES];
}

- (void)sortColumnOld:(PSColumn *)oldCol New:(PSColumn *)newCol desc:(BOOL)desc
{
	UILabel *label;
	if (oldCol && oldCol != newCol)
	if ((label = (UILabel *)[self viewWithTag:oldCol.tag + 1])) {
		//
        if (@available(iOS 13, *)) {
            label.textColor = [UIColor labelColor];
        } else {
            label.textColor = [UIColor blackColor];
        }
		label.text = oldCol.name;
	}
	if ((label = (UILabel *)[self viewWithTag:newCol.tag + 1])) {
        label.textColor = self.tintColor;
		label.text = [newCol.name stringByAppendingString:(desc ? @"\u25BC" : @"\u25B2")];
	}
}

- (void)updateSummaryWithColumns:(NSArray *)columns procs:(PSProcArray *)procs
{
	for (PSColumn *col in columns)
		if (col.getSummary) {
			UILabel *label = (UILabel *)[self viewWithTag:col.tag + 1];
			if (label) label.text = col.getSummary(procs);
		}
}

@end
