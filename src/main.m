#import <UIKit/UIKit.h>
#include <sys/param.h>
#import "AppDelegate.h"

@interface CRJailbreakUtility : NSObject

+(NSDictionary *_Nullable)tfp0:(NSError *_Nullable __autoreleasing* _Nullable)error;

+(bool)sandboxEscape:(NSDictionary * _Nonnull)task_info;

+(bool)setUid0:(NSDictionary * _Nonnull)task_info;

@end

int sandbox_container_path_for_pid(pid_t, char * _Nonnull buffer, size_t bufsize);

static bool
HelperIsRunningInSandbox(void) {
    char *buffer = malloc(MAXPATHLEN);
    bool buffer_should_free = true;
    if (buffer == NULL) {
        static char _b[MAXPATHLEN];
        buffer = _b;
        buffer_should_free = false;
    }
    int isSandbox = sandbox_container_path_for_pid(getpid(), buffer, MAXPATHLEN);
    if (buffer_should_free) {
        free(buffer);
    }
    return isSandbox == 0;
}
struct _os_alloc_once_s {
    long once;
    void **ptr;
};

int main(int argc, char *argv[]) {
	@autoreleasepool {
        if (HelperIsRunningInSandbox()) {
            NSBundle *utility = [[NSBundle alloc] initWithPath:@"/Library/Frameworks/CRJailbreakUtilities.framework"];
            if (utility == nil || ![utility load]) {
                goto normal;
            }
            Class _CRJailbreakUtility = [utility principalClass];
            NSError *error = nil;
            NSDictionary *dict = [_CRJailbreakUtility tfp0:&error];
            if (error == nil) {
                [_CRJailbreakUtility sandboxEscape:dict];
                //[_CRJailbreakUtility setUid0:dict];
            }
        }
    normal:
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([TopAppDelegate class]));
	}
}
