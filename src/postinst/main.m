//
//  main.m
//  CocoaTop
//
//  Created by SXX on 2021/1/4.
//  Copyright © 2021 SXX. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/stat.h>

#define APP_PATH_PREFIX "/Applications/CocoaTop.app"

int
main(int argc, char *argv[], char *envp[]) {
    if (geteuid() != 0) {
        printf("ERROR: This tool needs to be run as root.\n");
        return 1;
    }
    chown(APP_PATH_PREFIX "/CocoaTop", 0, 0);
    chmod(APP_PATH_PREFIX "/CocoaTop", 04755);
    if (@available(iOS 10, *)) {
    } else {
        chmod(APP_PATH_PREFIX "/CocoaTop_", 0755);
        rename(APP_PATH_PREFIX "/CocoaTop", APP_PATH_PREFIX "/CocoaTop1");
        rename(APP_PATH_PREFIX "/CocoaTop_", APP_PATH_PREFIX "/CocoaTop");
        rename(APP_PATH_PREFIX "/CocoaTop1", APP_PATH_PREFIX "/CocoaTop_");
    }
    return 0;
}
