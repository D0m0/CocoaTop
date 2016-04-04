#import <Foundation/NSPathUtilities.h>
#import "Compat.h"
#import "AppIcon.h"

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundle roleIdentifier:(id)role format:(int)format scale:(CGFloat)scale;
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundle format:(int)format scale:(CGFloat)scale;
@end

@implementation PSAppIcon

+ (NSDictionary *)getAppByPath:(NSString *)path
{
	return [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
}

+ (NSArray *)getIconFileForApp:(NSDictionary *)app
{
	@try {
		for (NSString *Key in @[@"CFBundleIcons~ipad", @"CFBundleIcons", @"CFBundleIconFiles", @"CFBundleIconFile"]) {
			id Value = app[Key], Try = nil;
			while ([Value isKindOfClass:[NSDictionary class]]) {
				for (NSString *Key2 in @[@"CFBundlePrimaryIcon", @"CFBundleIconFiles", @"CFBundleIconFile"])
					if ((Try = Value[Key2])) break;
				if (!Try) break;
				Value = Try;
			}
			Try = nil;
			while ([Value isKindOfClass:[NSArray class]] && [Value count]) {
				Try = Value; Value = Value[0];
			}
			if ([Value isKindOfClass:[NSString class]])
				return Try ? Try : @[Value];
		}
	}
	@finally {}
	return nil;
}

+ (NSString *)getIconFileForPath:(NSString *)path iconFiles:(NSArray *)icons
{
	NSArray* preferred = [@[@"Icon-76", @"Icon-60", @"icon_120x120", @"icon_80x80", @"Icon-Small-50", @"Icon-Small-40", @"Icon-Small"] arrayByAddingObjectsFromArray:icons];
	NSMutableArray *iconNames = [@[@"icon-about"] mutableCopy];		// for MobileCalendar
	for (NSString* icon in preferred)
		if ([icons containsObject:icon])
			[iconNames addObject:icon];
	for (NSString* icon in preferred)
		if (![icons containsObject:icon])
			[iconNames addObject:icon];
	NSFileManager *fileMgr = [NSFileManager defaultManager];
	NSString *iconFull;
	for (NSString *Icon in iconNames) {
		iconFull = [path stringByAppendingPathComponent:Icon];
		if (![Icon pathExtension].length) {
			for (NSString *IconExt in @[@"@3x.png", @"@2x~ipad.png", @"@2x.png", @"@2x~iphone.png", @"~ipad.png", @"~iphone.png", @".png"])
				if ([fileMgr fileExistsAtPath:[iconFull stringByAppendingString:IconExt]])
					return [iconFull stringByAppendingString:IconExt];
		}
		if ([fileMgr fileExistsAtPath:iconFull])
			return iconFull;
	}
	iconFull = [path stringByAppendingPathComponent:@"iTunesArtwork"];
	if ([fileMgr fileExistsAtPath:iconFull])
		return iconFull;
	return nil;
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

+ (UIImage *)getIconForApp:(NSDictionary *)app bundle:(NSString *)bundle path:(NSString *)path size:(NSInteger)dim
{
	NSString *iconPath = [PSAppIcon getIconFileForPath:path iconFiles:[PSAppIcon getIconFileForApp:app]];
	if (!iconPath)
		return nil;
	UIImage *image = [UIImage imageWithContentsOfFile:iconPath];
	if (!image)
		return nil;
//	NSLog(@"Icon(%fx%f) = %@", image.size.width, image.size.height, iconPath);
	if (image.size.height * image.scale < 58) {
		if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:roleIdentifier:format:scale:)])
			return [UIImage _applicationIconImageForBundleIdentifier:bundle roleIdentifier:nil format:1 scale:[UIScreen mainScreen].scale];
		else if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)])
			return [UIImage _applicationIconImageForBundleIdentifier:bundle format:1 scale:[UIScreen mainScreen].scale];
	}
	return [PSAppIcon roundCorneredImage:image size:dim radius:dim/4.5];
}

@end
