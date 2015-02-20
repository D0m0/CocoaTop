ARCHS = armv7
TARGET = iphone:clang:6.0
GO_EASY_ON_ME = 1

include theos/makefiles/common.mk

APPLICATION_NAME = DoomApp
DoomApp_FILES = main.m DoomAppAppDelegate.m RootViewController.m Setup.m SetupColumns.m About.m AppIcon.m Column.m GridCell.m Proc.m
DoomApp_FRAMEWORKS = UIKit CoreGraphics MessageUI

include $(THEOS_MAKE_PATH)/application.mk
