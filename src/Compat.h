#ifndef __IPHONE_6_0
#define __IPHONE_6_0 60000
#endif

#ifndef __IPHONE_7_0
#define __IPHONE_7_0 70000
#endif

#ifndef __IPHONE_8_0
#define __IPHONE_8_0 80000
#endif

#ifndef __IPHONE_9_0
#define __IPHONE_9_0 90000
#endif

#ifndef __MAC_10_9
#define __MAC_10_9 1090
#endif

#ifndef NSFoundationVersionNumber_iOS_6_0
#define NSFoundationVersionNumber_iOS_6_0 992.00
#endif

#ifndef NSFoundationVersionNumber_iOS_7_0
#define NSFoundationVersionNumber_iOS_7_0 1047.00
#endif

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_iOS_8_0 1134.0
#endif

#ifndef NSFoundationVersionNumber_iOS_9_0
#define NSFoundationVersionNumber_iOS_9_0 1221.0
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_7_0
#define UITableViewCellAccessoryDetailButton	UITableViewCellAccessoryDetailDisclosureButton
#define barTintColor							tintColor
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0

#undef YES
#undef NO
#define YES __objc_yes
#define NO __objc_no

#define NSLineBreakByWordWrapping				UILineBreakModeWordWrap
#define NSLineBreakByTruncatingMiddle			UILineBreakModeMiddleTruncation
#define NSTextAlignment							UITextAlignment
#define NSTextAlignmentLeft						UITextAlignmentLeft
#define NSTextAlignmentRight					UITextAlignmentRight
#define NSTextAlignmentCenter					UITextAlignmentCenter
#define NSFontAttributeName						UITextAttributeFont

@interface NSArray(Subscripts)
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
@end

@interface NSMutableArray(Subscripts)
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx;
@end

@interface NSDictionary(Subscripts)
- (id)objectForKeyedSubscript:(id)key;
@end

@interface NSMutableDictionary(Subscripts)
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;
@end

#define NSByteCountFormatterCountStyleMemory	1

@interface NSByteCountFormatter : NSObject
+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(int)countStyle;
@end

#define UITableViewHeaderFooterView				UIView

#define mach_task_basic_info_data_t				task_basic_info_data_t
#define MACH_TASK_BASIC_INFO					TASK_BASIC_INFO
#define MACH_TASK_BASIC_INFO_COUNT				TASK_BASIC_INFO_COUNT

#endif

uint64_t mach_time_to_milliseconds(uint64_t mach_time);


@interface PSSymLink : NSObject
+ (NSString *)simplifyPathName:(NSString *)path;
@end
