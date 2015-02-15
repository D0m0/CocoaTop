#import <UIKit/UIKit.h>

@interface PSAppIcon : NSObject
+ (NSDictionary *)getAppByPath:(NSString *)path;
+ (NSString *)getIconFileForPath:(NSString *)path iconFile:(NSString *)icon;
+ (UIImage *)getIconForApp:(NSDictionary *)app bundle:(NSString *)bundle path:(NSString *)path size:(NSInteger)dim;
@end
