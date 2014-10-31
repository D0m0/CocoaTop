#import <Foundation/NSPathUtilities.h>
#import "AppIcon.h"

@implementation PSAppIcon

+ (NSString *)psGetAppInfoPath
{
	NSArray *Array = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	if (Array.count)
		return [Array objectAtIndex:0];
	else
		return @"/var/mobile/Library/Caches";
}

- (instancetype)initWithAppKey:(NSDictionary *)app
{
	if (self = [super init]) {
		self.name = [app valueForKey:@"CFBundleIdentifier"];
//		self.bundleName = [app valueForKey:@"CFBundleName"];
//		self.displayName = [app valueForKey:@"CFBundleDisplayName"];
		self.path = [app valueForKey:@"Path"];

		NSMutableArray *IconNames = [NSMutableArray arrayWithObjects:@"Icon", @"icon", @"Icon-Small", @"Icon-Small-50", @"Icon-Small-40", @"icon-114", nil];
		for (NSString *Key in [NSArray arrayWithObjects:@"CFBundleIcons", @"CFBundleIconFiles", @"CFBundleIconFile", nil]) {
			id Value = [app valueForKey:Key];
			while ([Value isKindOfClass:[NSArray class]])
				Value = [Value objectAtIndex:0];
			if ([Value isKindOfClass:[NSString class]]) {
				[IconNames insertObject:Value atIndex:0];
				break;
			}
		}
		NSFileManager *fileMgr = [NSFileManager defaultManager];
		for (NSString *Icon in IconNames) {
			self.icon = [self.path stringByAppendingPathComponent:Icon];
			if ([[self.icon pathExtension] compare:@""]) {
				for (NSString *IconExt in [NSArray arrayWithObjects:@"@2x~ipad.png", @"@2x.png", @"@2x~iphone.png", @"~ipad.png", @"~iphone.png", @".png", nil])
					if ([fileMgr fileExistsAtPath:[self.icon stringByAppendingString:IconExt]]) {
						self.icon = [self.icon stringByAppendingString:IconExt];
						break;
					}
			}
			if (![fileMgr fileExistsAtPath:self.icon])
				self.icon = @"dhdhhd";
			if (![self.icon compare:@""])
				self.icon = @"bababa";
		}
	}
	return self;
}

+ (instancetype)psAppIconWithAppKey:(NSDictionary *)app
{
	return [[[PSAppIcon alloc] initWithAppKey:app] autorelease];
}

+ (NSArray *)psAppIconArray
{
	NSMutableArray *AppIconArray = [NSMutableArray array];
//	@autoreleasepool {
		NSDictionary *DicFile = [NSDictionary dictionaryWithContentsOfFile:
			[[self psGetAppInfoPath] stringByAppendingPathComponent:@"com.apple.mobile.installation.plist"]];
		NSDictionary *DicKeySyst = [DicFile objectForKey:@"System"];
/*		if (DicKeySyst)//[DicKeySyst.allKeys respondsToSelector:@selector(objectForKey)])
		{
			UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"OK" message:NSStringFromClass([DicKeySyst class])
				delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alertView show];
		}
*/		if (DicKeySyst)
		for (id App in DicKeySyst)
			[AppIconArray addObject:[PSAppIcon psAppIconWithAppKey:[DicKeySyst objectForKey:App]]];
/*		NSDictionary *DicKeyUser = [DicFile objectForKey:@"User"];
		for (NSDictionary *App in DicKeyUser)
			[AppIconArray addObject:[PSAppIcon psAppIconWithAppKey:App]];
//		AppInfoSorted = [AppInfoArray sortedArrayUsingFunction:alphabeticAppInfoSort context:Context];
//		self.AppInformationArray = AppInfoSorted;
*/
//	}
	return AppIconArray;
}

+ (UIImage *)roundCorneredImage:(UIImage *)orig size:(NSInteger)dim radius:(CGFloat)r
{
	CGSize size = (CGSize){dim, dim};
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[[UIBezierPath bezierPathWithRoundedRect:(CGRect){CGPointZero, size} cornerRadius:r] addClip];
	[orig drawInRect:(CGRect){CGPointZero, size}];
	UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

+ (NSString *)getIconFileFromArray:(NSArray *)appIconArray forApp:(NSString *)fullPath
{
	NSString *appPath = [fullPath stringByDeletingLastPathComponent];
	// Search for path
//	return [NSString stringWithFormat:@"%u", appIconArray.count];
	for (PSAppIcon *ic in appIconArray) {
		if (![ic.path compare:appPath])
			return ic.icon;
	}
	return appPath;
	NSArray *result = nil;//[appIconArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"([self.path compare:%@])", appPath]];
	if (0){//result.count) {
		PSAppIcon *ic = [result objectAtIndex:0];
		appPath = ic.icon;
	} else {
		appPath = [appPath stringByDeletingLastPathComponent];
		if ([[appPath stringByDeletingLastPathComponent] compare:@"/var/mobile/Applications"])
			return [fullPath lastPathComponent];
		appPath = [appPath stringByAppendingPathComponent:@"iTunesArtwork"];
	}
	return appPath;
}

+ (UIImage *)getIconFromArray:(NSArray *)appIconArray forApp:(NSString *)fullPath size:(NSInteger)dim;
{
	NSString *appPath = [fullPath stringByDeletingLastPathComponent];
	// Search for path
	NSArray *result = [appIconArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"([self.path compare:%@])", appPath]];
	if (result.count)
		appPath = [result objectAtIndex:0];
	else {
		appPath = [appPath stringByDeletingLastPathComponent];
		if (![appPath compare:@"/var/mobile/Applications"])
			return nil;
		appPath = [appPath stringByAppendingPathComponent:@"iTunesArtwork"];
	}
	UIImage *image = [UIImage imageWithContentsOfFile:appPath];
	if (!image)
		return nil;
	if (dim > image.size.width)
		dim = image.size.width;
	return [PSAppIcon roundCorneredImage:image size:dim radius:dim/5];
}

@end
