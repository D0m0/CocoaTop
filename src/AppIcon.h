#import <UIKit/UIKit.h>

@interface PSAppIcon : NSObject
{
}
@property (retain) NSString *name;
@property (retain) NSString *path;
@property (retain) NSString *icon;
//@property (assign) BOOL system;
- (instancetype)initWithAppKey:(NSDictionary *)app;
+ (instancetype)psAppIconWithAppKey:(NSDictionary *)app;
+ (NSArray *)psAppIconArray;
+ (UIImage *)getIconFromArray:(NSArray *)appIconArray forApp:(NSString *)fullPath size:(NSInteger)dim;

@end
