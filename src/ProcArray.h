#import "Proc.h"
#import "NetArray.h"

@interface PSProcInfo : NSObject
{
@public struct kinfo_proc *kp;
@public size_t count;
@public int ret;
}
+ (instancetype)psProcInfoSort:(BOOL)sort;
@end

@interface PSProcArray : NSObject
@property (strong) NSMutableArray *procs;
@property (strong) PSNetArray *nstats;
@property (assign) CGFloat iconSize;
@property (assign) uint64_t memUsed;
@property (assign) uint64_t memFree;
@property (assign) uint64_t memTotal;
@property (assign) unsigned int totalCpu;
@property (assign) unsigned int threadCount;
@property (assign) unsigned int portCount;
@property (assign) unsigned int machCalls;
@property (assign) unsigned int unixCalls;
@property (assign) unsigned int switchCount;
@property (assign) unsigned int guiCount;
@property (assign) unsigned int mobileCount;
@property (assign) unsigned int runningCount;
@property (assign) unsigned int coresCount;
+ (instancetype)psProcArrayWithIconSize:(CGFloat)size;
- (int)refresh;
- (void)sortUsingComparator:(NSComparator)comp desc:(BOOL)desc;
- (void)setAllDisplayed:(display_t)display;
- (NSUInteger)indexOfDisplayed:(display_t)display;
- (NSUInteger)count;
- (PSProc *)objectAtIndexedSubscript:(NSUInteger)idx;
- (NSUInteger)indexForPid:(pid_t)pid;
- (PSProc *)procForPid:(pid_t)pid;
@end
