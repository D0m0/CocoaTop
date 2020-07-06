# CocoaTop
CocoaTop: Process Viewer for iOS GUI

This fork adds full iOS 13 support, including safe area on iPhone X screen,  dark mode and split view on iPad.

Tested on devices from iOS 6 to 13.

I'm releasing the source code for everyone to improve. The license is GPL-3, except for the include files in *kern*, *net*, *netinet*, *sys*, and *xpc* folders. These are taken from public Mach kernel code and put here to simplify building. You are free to modify the *About* text (a.k.a. *The Story*) any way you want, but I will appreciate if you leave a few honorable mentions with links:
* Jonathan Levin (http://newosxbook.com/) who gave a deep insight into iOS internals.
* @DylanDuff3 (http://twitter.com/dylanduff3) who created the icon.
* Domo (https://github.com/D0m0/), who is the original author.

The main challenge is porting the code to modern iOS SDKs by replacing deprecated methods with new ones. This is actually a lot of work, and I don't have the time to do it on my own.

To build CocoaTop you need:
* Theos (https://github.com/theos/theos), make sure $(THEOS) environment variable points to it.
* Appe iOS SDK (currently version 7.0 is used). Download it from Apple and unpack to theos\sdks\. Also look here: https://github.com/theos/sdks/
* make!

Other build commands:
* *make package* - create a Cydia .deb package.
* *make TARGET=iphone:clang:5.0 SCHEMA=five* - build for iOS 5.
* *make TARGET=iphone:clang:6.0 SCHEMA=six* - build for iOS 6.
* *make install THEOS_DEVICE_IP=192.168.1.222 THEOS_DEVICE_PORT=22* - install package .deb to device using SSH.
