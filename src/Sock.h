#import "Proc.h"

@interface PSSock : NSObject
@property (assign) display_t display;
@property (assign) int32_t fd;
@property (assign) uint32_t type;
@property (retain) NSString *name;
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
