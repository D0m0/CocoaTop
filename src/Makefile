ARCHS = armv7
TARGET = iphone:clang:7.0
GO_EASY_ON_ME = 1

include theos/makefiles/common.mk

APPLICATION_NAME = CocoaTop
CocoaTop_FILES = main.m AppDelegate.m RootViewController.m Setup.m SetupColumns.m About.m AppIcon.m Column.m GridCell.m Proc.m
CocoaTop_FRAMEWORKS = UIKit CoreGraphics MessageUI

include $(THEOS_MAKE_PATH)/application.mk

after-all::
	@ldid -Stask.xml obj/CocoaTop.app/CocoaTop

before-package::
	@cp postinst _/DEBIAN/postinst
