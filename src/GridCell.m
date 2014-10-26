//#import <QuartzCore/QuartzCore.h>
#import "GridCell.h"
#import "Proc.h"
#import "Column.h"

@implementation GridTableCell

/*

// ACApplicationInfoAdBlocker - (id)initWithMobileInstallationCacheAppDict:(id) appType:(int) 
id __cdecl -[ACApplicationInfoAdBlocker initWithMobileInstallationCacheAppDict:appType:](struct ACApplicationInfoAdBlocker *self, SEL a2, id appDict, int appType)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	void *BundleIconFiles;
	void *BundleIconFile;

	if (self = [super init]) {
		self.bundleIdentifier = [appDict valueForKey:@"CFBundleIdentifier"];
		self.bundleName = [appDict valueForKey:@"CFBundleName"];
		self.path = [appDict valueForKey:@"Path"];
		BundleIconFile = [appDict valueForKey:@"CFBundleIconFile"];
		BundleIconFiles = [appDict valueForKey:@"CFBundleIconFiles"];
		if ([BundleIconFile isKindOfClass:[NSString class]] != 1) {
			if ([BundleIconFile isKindOfClass:[NSString class]] == 1 && !BundleIconFiles)
				BundleIconFiles = [appDict valueForKey:@"CFBundleIconFile"];
			BundleIconFile = 0;
			if ([BundleIconFiles isKindOfClass:[NSArray class]]) {
				if ([BundleIconFiles respondsToSelector:@"lastObject"]) {
					if ([BundleIconFiles respondsToSelector:@"count"]) {
						if (BundleIconFiles.count) {
							BundleIconFile = [BundleIconFiles objectAtIndex:0];
							if ([BundleIconFile isKindOfClass:[NSArray class]] == 1)
								BundleIconFile = [BundleIconFile objectAtIndex:0];
						}
					}
				}
			}
		}
		if (BundleIconFile &&
			[fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
			// Bred...
			if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]])
				BundleIconFile = objc_msgSend(BundleIconFile, "stringByAppendingString:", @".png");
		} else {
			BundleIconFile = @"Icon@2x.png";
			if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
				BundleIconFile = @"icon@2x.png";
				if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
					BundleIconFile = @"Icon.png";
					if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
						BundleIconFile = @"icon.png";
						if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
							BundleIconFile = @Icon-Small-50.png";
							if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
								BundleIconFile = @"Icon-Small.png";
								if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
									BundleIconFile = @"icon@2x~iphone.png";
									if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
										BundleIconFile = @"icon~iphone.png";
										if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]]) {
											BundleIconFile = @"icon~ipad.png";
											if (![fileManager fileExistsAtPath:[self.path stringByAppendingPathComponent:BundleIconFile]])
												BundleIconFile = @"icon-114.png";
										}
									}
								}
							}
						}
					}
				}
			}
		}
		self.iconPath = [self.path stringByAppendingPathComponent:BundleIconFile];
		if (![fileManager fileExistsAtPath:self.iconPath])
			self.iconPath = nil;
		self.icon = nil;
		self.displayName = [appDict valueForKey:@"CFBundleDisplayName"];
		if (!self.displayName)
			if (self.bundleName)
				self.displayName = self.bundleName;
			else
				self.displayName = [[self.path, lastPathComponent] stringByDeletingPathExtension];
		self.appType = appType;
		self.hasInfo = YES;
	}
	return self;
}

// Search for path
NSArray *resultArray = [[mainDict allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(key1 == %@) AND (key2==%@)", @"tt",@"vv"]];
*/

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
	// Get application icon
	if (proc.icon) {
		[cell.imageView initWithImage:proc.icon];
		firstCol -= size.height; //proc.icon.size.width;
	}
	// Get other columns
	self.labels = [[NSMutableArray arrayWithCapacity:columns.count-1] retain];
	self.dividers = [[NSMutableArray arrayWithCapacity:columns.count-1] retain];
	for (int i = 1; i < columns.count /*&& totalCol < size.width*/; i++) {
		UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(totalCol, 0, 1, size.height)];
		[self.dividers addObject:divider];
		[divider release];
		divider.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
		[cell.contentView addSubview:divider];

		PSColumn *col = [columns objectAtIndex:i];
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(totalCol + 4, 0, col.width - 8, size.height)];
		[self.labels addObject:label];
		[label release];
		label.textAlignment = col.align;
		label.font = [UIFont systemFontOfSize:12.0];
		label.text = [col getDataForProc:proc];
		label.backgroundColor = [UIColor clearColor];
		label.tag = i;
		[cell.contentView addSubview:label];
		totalCol += col.width;
	}
	return cell;
}

+ (instancetype)cellWithId:(NSString *)reuseIdentifier proc:(PSProc *)proc columns:(NSArray *)columns size:(CGSize)size
{
	return [[[GridTableCell alloc] initWithId:reuseIdentifier proc:proc columns:columns size:size] autorelease];
}

- (void)updateWithProc:(PSProc *)proc columns:(NSArray *)columns
{
	for (int i = 1; i < columns.count; i++) {
		PSColumn *col = [columns objectAtIndex:i];
		UILabel *label = (UILabel *)[self viewWithTag:i];
		if (col.refresh)
			label.text = [col getDataForProc:proc];
	}
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
