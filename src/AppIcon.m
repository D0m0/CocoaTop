#import <Foundation/NSPathUtilities.h>
#import "AppIcon.h"

@implementation PSAppIcon

+ (NSDictionary *)getAppByPath:(NSString *)path
{
	return [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
}

+ (NSString *)getIconFileForApp:(NSDictionary *)app
{
	@try {
		for (NSString *Key in [NSArray arrayWithObjects:@"CFBundleIcons~ipad", @"CFBundleIcons", @"CFBundleIconFiles", @"CFBundleIconFile", nil]) {
			id Value = [app valueForKey:Key];
			while ([Value isKindOfClass:[NSDictionary class]]) {
				id        Try = [Value valueForKey:@"CFBundlePrimaryIcon"];
				if (!Try) Try = [Value valueForKey:@"CFBundleIconFiles"];
				if (!Try) Try = [Value valueForKey:@"CFBundleIconFile"];
				if (!Try) break;
				Value = Try;
			}
			while ([Value isKindOfClass:[NSArray class]] && [Value count])
				Value = [Value objectAtIndex:0];
			if ([Value isKindOfClass:[NSString class]])
				return Value;
		}
	}
	@finally {}
	return nil;
}

+ (NSString *)getIconFileForPath:(NSString *)path iconFile:(NSString *)icon
{
	NSMutableArray *iconNames = [NSMutableArray arrayWithObjects:@"Icon", @"icon", @"Icon-Small", @"Icon-Small-50", @"Icon-Small-40", @"icon-114", nil];
	if (icon)
		[iconNames insertObject:icon atIndex:0];
	NSFileManager *fileMgr = [NSFileManager defaultManager];
	NSString *iconFull;
	for (NSString *Icon in iconNames) {
		iconFull = [path stringByAppendingPathComponent:Icon];
		if (![iconFull pathExtension].length) {
			for (NSString *IconExt in [NSArray arrayWithObjects:@"@2x~ipad.png", @"@2x.png", @"@2x~iphone.png", @"~ipad.png", @"~iphone.png", @".png", nil])
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
	NSString *iconFile = [PSAppIcon getIconFileForApp:app];
	if (!iconFile)
		return nil;
	NSString *iconPath = [PSAppIcon getIconFileForPath:path iconFile:iconFile];
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
