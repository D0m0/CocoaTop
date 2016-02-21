ARCHS = armv7
TARGET = iphone:clang:7.0
APPLICATION_NAME = CocoaTop
CocoaTop_FILES = RootViewController.m SockViewController.m Proc.m ProcArray.m NetArray.m Sock.m Column.m GridCell.m Setup.m SetupColumns.m AppIcon.m TextViewController.m THtmlViewController.m PopupMenuView.m BackButtonHandler.m Compat.m AppDelegate.m main.m
CocoaTop_FRAMEWORKS = UIKit CoreGraphics MessageUI
CocoaTop_CODESIGN_FLAGS = -Stask.xml
ifeq ($(TARGET),iphone:clang:7.0)
CocoaTop_RESOURCE_DIRS = res
endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk

before-package::
	@cp obj/five/CocoaTop.app/CocoaTop _/Applications/CocoaTop.app/CocoaTop5
	@cp obj/six/CocoaTop.app/CocoaTop _/Applications/CocoaTop.app/CocoaTop6
	@cp postinst _/DEBIAN/postinst
