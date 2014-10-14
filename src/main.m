
#import <UIKit/UIKit.h>

#import "DoomAppAppDelegate.h"

int main(int argc, char *argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	int retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass([DoomAppAppDelegate class]));
	[pool release];
	return retVal;
}
