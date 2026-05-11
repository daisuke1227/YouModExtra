TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TweakLoader

TweakLoader_FILES = TweakLoader.m
TweakLoader_CFLAGS = -fobjc-arc
TweakLoader_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
