# CocoaTop
CocoaTop: Process Viewer for iOS GUI

I'm releasing the source code for everyone to improve. The license is GPL-3, except for the include files in *kern*, *net*, *netinet*, *sys*, and *xpc* folders. These are taken from public Mach kernel code and put here to simplify building.

The main challenge is porting the code to modern iOS SDKs by replacing deprecated methods with new ones. This is actually a lot of work, and I don't have the time to do it on my own.

If you are willing to port CocoaTop to iOS 10, 11, 12, etc., please bear in mind the following:
* It would be a good idea to build for arm64 platform. The code is already adapted, you need to set "ARCHS = arm64" in the Makefile.
* Feel free to remove support for old iOSes (5, 6, 7, 8, etc...)

To build CocoaTop you need:
* Theos (https://github.com/theos/theos), make sure $(THEOS) environment variable points to it.
* Appe iOS SDK (currently version 7.0 is used). Download it from Apple and unpack to theos\sdks\. Also look here: https://github.com/theos/sdks/
* make!

Other build commands:
* *make package* - create a Cydia .deb package.
* *make TARGET=iphone:clang:5.0 SCHEMA=five* - build for iOS 5.
* *make TARGET=iphone:clang:6.0 SCHEMA=six* - build for iOS 6.
* *make install THEOS_DEVICE_IP=192.168.1.222 THEOS_DEVICE_PORT=22* - install package .deb to device using SSH.
