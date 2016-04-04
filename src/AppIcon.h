#import <UIKit/UIKit.h>

@interface PSAppIcon : NSObject
+ (NSDictionary *)getAppByPath:(NSString *)path;
+ (UIImage *)getIconForApp:(NSDictionary *)app bundle:(NSString *)bundle path:(NSString *)path size:(NSInteger)dim;
@end
