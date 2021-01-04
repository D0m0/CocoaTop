ARCHS = armv7 arm64
TARGET = iphone:clang:13.0:6.0
include $(THEOS)/makefiles/common.mk

TOOL_NAME = postinst

postinst_FILES = main.m
postinst_CFLAGS += -fvisibility=hidden -DPOSTINST -fobjc-arc
postinst_INSTALL_PATH = /DEBIAN
postinst_CODESIGN_FLAGS = -Stask.xml

include $(THEOS_MAKE_PATH)/tool.mk

include $(THEOS_MAKE_PATH)/aggregate.mk
