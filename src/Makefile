ARCHS = armv7
TARGET = iphone:clang:7.0
GO_EASY_ON_ME = 1

include theos/makefiles/common.mk

APPLICATION_NAME = CocoaTop
CocoaTop_FILES = RootViewController.m SockViewController.m Proc.m ProcArray.m NetArray.m Sock.m Column.m GridCell.m Setup.m SetupColumns.m AppIcon.m TextViewController.m THtmlViewController.m BackButtonHandler.m Compat.m AppDelegate.m main.m
CocoaTop_FRAMEWORKS = UIKit CoreGraphics MessageUI
CocoaTop_CODESIGN_FLAGS = -Stask.xml

include $(THEOS_MAKE_PATH)/application.mk

before-package::
	@cp postinst _/DEBIAN/postinst
