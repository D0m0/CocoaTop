ARCHS = armv7
TARGET = iphone:clang:7.0
GO_EASY_ON_ME = 1

include theos/makefiles/common.mk

APPLICATION_NAME = CocoaTop
CocoaTop_FILES = SetupColumns.m Compat.m Proc.m ProcArray.m Sock.m RootViewController.m SockViewController.m Column.m GridCell.m Setup.m About.m AppIcon.m AppDelegate.m main.m
CocoaTop_FRAMEWORKS = UIKit CoreGraphics MessageUI

include $(THEOS_MAKE_PATH)/application.mk

after-all::
	@ldid -Stask.xml obj/CocoaTop.app/CocoaTop

before-package::
	@cp postinst _/DEBIAN/postinst
