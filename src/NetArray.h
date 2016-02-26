@class PSProcArray;

@interface PSNetArray : NSObject
@property (strong) NSMutableDictionary *nstats;
@property (assign) unsigned int tcp;
@property (assign) unsigned int udp;
@property (assign) CFSocketRef netStat;
@property (assign) CFDataRef netStatAddr;
+ (instancetype)psNetArray;
- (void)reopen;
- (void)query;
- (void)refresh:(PSProcArray *)procs;
@end
