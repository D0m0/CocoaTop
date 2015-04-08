#import "Compat.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0

@implementation NSArray(Subscripts)
- (id)objectAtIndexedSubscript:(NSUInteger)idx { return [self objectAtIndex:idx]; }
@end

@implementation NSDictionary(Subscripts)
- (id)objectForKeyedSubscript:(id)key { return [self objectForKey:key]; }
@end

@implementation NSByteCountFormatter
+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(int)countStyle { return [NSString stringWithFormat:@"%.1f MB", (float)byteCount / 1024 / 1024]; }
@end

#endif
