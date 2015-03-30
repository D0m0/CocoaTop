#import "Proc.h"
#import "Compat.h"

#define KEV_ANY_VENDOR				0
#define KEV_ANY_CLASS				0
#define KEV_ANY_SUBCLASS			0

// All kernel event classes and subclasses. Thanks, Google!
#define KEV_VENDOR_APPLE			1
#define KEV_NETWORK_CLASS			1
#define		KEV_INET_SUBCLASS			1
#define		KEV_DL_SUBCLASS				2
#define		KEV_NETPOLICY_SUBCLASS		3
#define		KEV_ATALK_SUBCLASS			5
#define		KEV_INET6_SUBCLASS			6
#define		KEV_LOG_SUBCLASS			10
#define KEV_IOKIT_CLASS				2
#define KEV_SYSTEM_CLASS			3
#define		KEV_CTL_SUBCLASS			2
#define		KEV_MEMORYSTATUS_SUBCLASS	3
#define KEV_APPLESHARE_CLASS		4
#define KEV_FIREWALL_CLASS			5
#define		KEV_IPFW_SUBCLASS			1
#define		KEV_IP6FW_SUBCLASS			2
#define KEV_IEEE80211_CLASS			6

@interface PSSock : NSObject
@property (assign) display_t display;
@property (assign) int32_t fd;
@property (assign) uint32_t type;
@property (retain) NSString *name;
@property (retain) NSString *stype;
@property (retain) UIColor *color;
+ (instancetype)psSockWithPid:(pid_t)pid fd:(int32_t)fd type:(uint32_t)type;
@end

@interface PSSockArray : NSObject
@property (assign) pid_t pid;
@property (retain) NSMutableArray *socks;
+ (instancetype)psSockArrayWithPid:(pid_t)pid;
- (int)refresh;
- (void)sortUsingComparator:(NSComparator)comp desc:(BOOL)desc;
- (void)setAllDisplayed:(display_t)display;
- (NSUInteger)indexOfDisplayed:(display_t)display;
- (NSUInteger)count;
- (PSSock *)objectAtIndexedSubscript:(NSUInteger)idx;
- (PSSock *)sockForFd:(int32_t)fd;
@end
