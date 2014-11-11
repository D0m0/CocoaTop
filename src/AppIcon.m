#import <Foundation/NSPathUtilities.h>
//#import <AppList/ALApplicationList.h>
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

		NSLog(@"self.name = %@", self.name);
		NSLog(@"self.path = %@", self.path);

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
//	NSMutableArray *AppIconArray = [NSMutableArray array];

	// list all the apps
	ALApplicationList *apps = [ALApplicationList sharedApplicationList];
 
	// sort the apps by display name. displayIdentifiers is an autoreleased object.
	NSArray *displayIdentifiers = [apps.applications allKeys];
//	[[apps.applications allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
//		return [[apps.applications objectForKey:obj1] caseInsensitiveCompare:[apps.applications objectForKey:obj2]];
//	}];
/*	for (NSString *key in displayIdentifiers) {
//		id app = [apps.applications objectForKey:key];
//		NSString *path = NSStringFromClass([app class]);//[app objectForKey:@"path"];
//		NSDictionary *app = [apps.applications objectForKey:key];
		NSLog(@"%@", key);
		//id app = [apps valueForKey:@"path" forDisplayIdentifier:[apps.applications objectForKey:key]];
		//SBApplication *app = [SBApplication applicationWithBundleIdentifier:key];
		SBApplication *app = [[SBApplicationController sharedInstance] applicationWithDisplayIdentifier:key];
		NSLog(@"App: %@", app);
//		NSBundle *myBundle = [NSBundle bundleWithIdentifier:key];
//		NSLog(@"Path: %@", [myBundle bundlePath]);
//		NSLog(@"Dict: %@", [myBundle infoDictionary]);
	}
*/
	Class SBApplicationController = objc_getClass("SBApplicationController");
NSLog(@"SBApplicationController: %@", SBApplicationController);
	Class SBApplication = objc_getClass("SBApplication");
NSLog(@"SBApplication: %@", SBApplication);
	id controller = [SBApplicationController sharedInstance];
NSLog(@"ctrlid: %@", controller);
	for (NSString *appId in [controller allBundleIdentifiers]) { 
		NSLog (@"bundle: %@", appId);
//		NSLog ([NSString stringWithFormat:@"bundle: %@", appId]);
		NSArray *apps = [controller applicationsWithBundleIdentifier:appId];
		if ([apps count] > 0) { 
			id app = [apps objectAtIndex:0]; 
//			[self indexApp:app withName:[app displayName]];
			NSLog(@"App: %@", [app displayName]);
		}
	}
	return displayIdentifiers;
//	@autoreleasepool {
/*		NSDictionary *DicFile = [NSDictionary dictionaryWithContentsOfFile:
			[[self psGetAppInfoPath] stringByAppendingPathComponent:@"com.apple.mobile.installation.plist"]];
		NSDictionary *DicKeySyst = [DicFile objectForKey:@"System"];
		if (DicKeySyst)//[DicKeySyst.allKeys respondsToSelector:@selector(objectForKey)])
		{
			UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"OK" message:NSStringFromClass([DicKeySyst class])
				delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alertView show];
		}
		if (DicKeySyst)
		for (id App in DicKeySyst)
			[AppIconArray addObject:[PSAppIcon psAppIconWithAppKey:[DicKeySyst objectForKey:App]]];
		NSDictionary *DicKeyUser = [DicFile objectForKey:@"User"];
		for (NSDictionary *App in DicKeyUser)
			[AppIconArray addObject:[PSAppIcon psAppIconWithAppKey:App]];
//		AppInfoSorted = [AppInfoArray sortedArrayUsingFunction:alphabeticAppInfoSort context:Context];
//		self.AppInformationArray = AppInfoSorted;
*/
//	}
//	return AppIconArray;
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
//	NSString *appPath = [fullPath stringByDeletingLastPathComponent];
	// Search for path
	return fullPath;
//	return [NSString stringWithFormat:@"%u", appIconArray.count];
/*	for (PSAppIcon *ic in appIconArray) {
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
*/
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
