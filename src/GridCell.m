#import "GridCell.h"
#import "Proc.h"
#import "Column.h"

@implementation GridTableCell

/*
#import <Foundation/NSPathUtilities.h>

  NSArray *Array = NSSearchPathForDirectoriesInDomains(NSCachesDirectory);
  DicPath = nil;
  if (Array.count) {
    DicPath = [[Array objectAtIndex:0] stringByAppendingPathComponent:@"com.apple.mobile.installation.plist"];

    DicFile = [NSDictionary dictionaryWithContentsOfFile:DicPath];
    DicKeySyst = [DicFile objectForKey:@"System"];
    DicKeyUser = [DicFile objectForKey:@"User"];
    AppInfoArray = [NSMutableArray array];

    AllKeysUser = objc_msgSend(DicKeyUser, "allKeys");
    UserCount = objc_msgSend(AllKeysUser, "countByEnumeratingWithState:objects:count:", &v41, &v40, 16);
    if ( UserCount ) {
        NextUserKey = *(_DWORD *)(v42 + 4 * v27);
        NextUserObj = [DicKeyUser objectForKey:NextUserKey];
        AppInfo = [[ACApplicationInfoAdBlocker alloc] initWithMobileInstallationCacheAppDict:NextUserObj appType:1]
        [AppInfoArray addObject:AppInfo];
        [AppInfo release];

        if ( ++v27 >= (unsigned int)UserCount ) {
          UserCount = objc_msgSend(AllKeysUser, "countByEnumeratingWithState:objects:count:", &v41, &v40, 16);
          if ( !UserCount ) break;
        }
    }
    Context = 0;
    AppInfoSorted = [AppInfoArray sortedArrayUsingFunction:alphabeticAppInfoSort context:Context];
    self.AppInformationArray = AppInfoSorted;
  }


// ACApplicationInfoAdBlocker - (id)initWithMobileInstallationCacheAppDict:(id) appType:(int) 
id __cdecl -[ACApplicationInfoAdBlocker initWithMobileInstallationCacheAppDict:appType:](struct ACApplicationInfoAdBlocker *self, SEL a2, id appDict, int appType)
{
	if (self = [super init]) {
		self.bundleIdentifier = [appDict valueForKey:@"CFBundleIdentifier"];
		self.bundleName = [appDict valueForKey:@"CFBundleName"];
		self.path = [appDict valueForKey:@"Path"];
		id IconFile = [appDict valueForKey:@"CFBundleIconFile"];
		if (![IconFile isKindOfClass:[NSString class]]) {
			IconFile = [appDict valueForKey:@"CFBundleIconFiles"];
			while ([IconFile isKindOfClass:[NSArray class]])
				IconFile = [IconFile lastObject];
		}
		NSFileManager *fileMgr = [NSFileManager defaultManager];
		if ([IconFile isKindOfClass:[NSString class]])
		for (NSString *Icon in [NSArray arrayWithObjects:IconFile, [IconFile stringByAppendingString:@".png"], nil])
			if ([fileMgr fileExistsAtPath:[self.path stringByAppendingPathComponent:Icon]]) {
				self.iconPath = [self.path stringByAppendingPathComponent:Icon];
				break;
			}
		if (!self.iconPath)
		for (NSString *Icon in [NSArray arrayWithObjects:@"Icon@2x.png", @"icon@2x.png", @"Icon.png", @"icon.png", @Icon-Small-50.png",
			@"Icon-Small.png", @"icon@2x~iphone.png", @"icon~iphone.png", @"icon~ipad.png", @"icon-114.png", nil])
			if ([fileMgr fileExistsAtPath:[self.path stringByAppendingPathComponent:Icon]]) {
				self.iconPath = [self.path stringByAppendingPathComponent:Icon];
				break;
			}
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
