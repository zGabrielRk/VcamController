TARGET := iphone:clang:latest:16.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VcamCompanion
VcamCompanion_FILES = Tweak.m
VcamCompanion_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
