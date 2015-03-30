#ifndef __IPHONE_6_0
#define __IPHONE_6_0 60000
#endif

#ifndef __IPHONE_7_0
#define __IPHONE_7_0 70000
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0

#undef YES
#undef NO
#define YES __objc_yes
#define NO __objc_no

#define NSLineBreakByWordWrapping				UILineBreakModeWordWrap
#define NSTextAlignment							UITextAlignment
#define NSTextAlignmentLeft						UITextAlignmentLeft
#define NSTextAlignmentRight					UITextAlignmentRight
#define NSTextAlignmentCenter					UITextAlignmentCenter
#define NSFontAttributeName						UITextAttributeFont

@interface NSArray(Subscripts)
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
@end

@interface NSDictionary(Subscripts)
- (id)objectForKeyedSubscript:(id)key;
@end

#define NSByteCountFormatterCountStyleMemory	1

@interface NSByteCountFormatter : NSObject
+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(int)countStyle;
@end

#define UITableViewHeaderFooterView				UIView

#endif
