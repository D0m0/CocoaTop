ARCHS = armv7
TARGET = iphone:clang:7.0
GO_EASY_ON_ME = 1

include theos/makefiles/common.mk

APPLICATION_NAME = CocoaTop
CocoaTop_FILES = THtmlViewController.m RootViewController.m SockViewController.m Proc.m ProcArray.m NetArray.m Sock.m Column.m GridCell.m Setup.m SetupColumns.m About.m AppIcon.m TextViewController.m Compat.m AppDelegate.m main.m
CocoaTop_FRAMEWORKS = UIKit CoreGraphics MessageUI

include $(THEOS_MAKE_PATH)/application.mk

after-all::
	@ldid -Stask.xml obj/CocoaTop.app/CocoaTop

before-package::
	@cp postinst _/DEBIAN/postinst
