# CocoaTop
CocoaTop: Process Viewer for iOS GUI

Current 64-bit version should work on iOS 10-13, with support for safe area on iPhone X screen, dark mode, and split view on iPad!

Versions prior to 2.0.1 are 32 bit and work on iOS 6-10. If you want to build those, checkout a 2019 commit.

Source code is available for everyone to improve. The license is GPL-3, except for the include files in *kern*, *net*, *netinet*, *sys*, and *xpc* folders. These are taken from public Mach kernel code and put here to simplify building. You are free to modify the *About* text (a.k.a. *The Story*) any way you want, but I will appreciate if you keep the "Developers" section up-to-date.

To build CocoaTop you need:
* Theos (https://github.com/theos/theos), make sure $(THEOS) environment variable points to it.
* Appe iOS SDK (currently version 7.0 is used). Download it from Apple and unpack to theos\sdks\. Also look here: https://github.com/theos/sdks/
* make
* make package
