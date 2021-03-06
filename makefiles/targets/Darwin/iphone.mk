ifeq ($(_THEOS_TARGET_LOADED),)
_THEOS_TARGET_LOADED := 1
THEOS_TARGET_NAME := iphone

ifeq ($(__THEOS_TARGET_ARG_1),clang)
_THEOS_TARGET_CC := clang
_THEOS_TARGET_CXX := clang++
_THEOS_TARGET_ARG_ORDER := 2 3
else
_THEOS_TARGET_CC := gcc
_THEOS_TARGET_CXX := g++
_THEOS_TARGET_ARG_ORDER := 1 2
endif
_THEOS_TARGET_CC_CFLAGS :=

# A version specified as a target argument overrides all previous definitions.
_SDKVERSION := $(or $(__THEOS_TARGET_ARG_$(word 1,$(_THEOS_TARGET_ARG_ORDER))),$(SDKVERSION_$(THEOS_CURRENT_ARCH)),$(SDKVERSION))
_THEOS_TARGET_SDK_VERSION := $(or $(_SDKVERSION),latest)
_THEOS_TARGET_INCLUDE_SDK_VERSION := $(or $(INCLUDE_SDKVERSION),$(INCLUDE_SDKVERSION_$(THEOS_CURRENT_ARCH)),latest)

_SDK_DIR := $(THEOS_PLATFORM_SDK_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs
_IOS_SDKS := $(sort $(patsubst $(_SDK_DIR)/iPhoneOS%.sdk,%,$(wildcard $(_SDK_DIR)/iPhoneOS*.sdk)))
_LATEST_SDK := $(word $(words $(_IOS_SDKS)),$(_IOS_SDKS))

ifeq ($(_THEOS_TARGET_SDK_VERSION),latest)
override _THEOS_TARGET_SDK_VERSION := $(_LATEST_SDK)
endif

ifeq ($(_THEOS_TARGET_INCLUDE_SDK_VERSION),latest)
override _THEOS_TARGET_INCLUDE_SDK_VERSION := $(_LATEST_SDK)
endif

# We have to figure out the target version here, as we need it in the calculation of the deployment version.
_TARGET_VERSION_GE_7_0 = $(call __simplify,_TARGET_VERSION_GE_7_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 7.0))
_TARGET_VERSION_GE_6_0 = $(call __simplify,_TARGET_VERSION_GE_6_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 6.0))
_TARGET_VERSION_GE_3_0 = $(call __simplify,_TARGET_VERSION_GE_3_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_SDK_VERSION) ge 3.0))

ifeq ($(_TARGET_VERSION_GE_7_0),1)
_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION := 5.0
else
ifeq ($(_TARGET_VERSION_GE_6_0),1)
_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION := 4.3
else
_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION := 3.0
endif
endif

_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION := $(or $(__THEOS_TARGET_ARG_$(word 2,$(_THEOS_TARGET_ARG_ORDER))),$(TARGET_IPHONEOS_DEPLOYMENT_VERSION_$(THEOS_CURRENT_ARCH)),$(TARGET_IPHONEOS_DEPLOYMENT_VERSION),$(_SDKVERSION),$(_THEOS_TARGET_DEFAULT_IPHONEOS_DEPLOYMENT_VERSION))

ifeq ($(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION),latest)
override _THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION := $(_LATEST_SDK)
endif

_DEPLOY_VERSION_GE_5_0 = $(call __simplify,_DEPLOY_VERSION_GE_5_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION) ge 5.0))
_DEPLOY_VERSION_GE_3_0 = $(call __simplify,_DEPLOY_VERSION_GE_3_0,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION) ge 3.0))
_DEPLOY_VERSION_LT_4_3 = $(call __simplify,_DEPLOY_VERSION_LT_4_3,$(shell $(THEOS_BIN_PATH)/vercmp.pl $(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION) lt 4.3))

ifeq ($(_TARGET_VERSION_GE_6_0)$(_DEPLOY_VERSION_GE_3_0)$(_DEPLOY_VERSION_LT_4_3),111)
ifeq ($(ARCHS)$(IPHONE_ARCHS)$(_THEOS_TARGET_WARNED_DEPLOY),)
$(warning Deploying to iOS 3.0 while building for 6.0 will generate armv7-only binaries.)
export _THEOS_TARGET_WARNED_DEPLOY := 1
endif
endif

ifeq ($(SYSROOT),)
SYSROOT ?= $(THEOS_PLATFORM_SDK_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(_THEOS_TARGET_SDK_VERSION).sdk
ISYSROOT ?= $(THEOS_PLATFORM_SDK_ROOT)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(_THEOS_TARGET_INCLUDE_SDK_VERSION).sdk
else
ISYSROOT ?= $(SYSROOT)
endif

TARGET_CC ?= xcrun -sdk iphoneos $(_THEOS_TARGET_CC)
TARGET_CXX ?= xcrun -sdk iphoneos $(_THEOS_TARGET_CXX)
TARGET_SWIFT = xcrun -sdk iphoneos swift
TARGET_LD ?= xcrun -sdk iphoneos $(_THEOS_TARGET_CXX)
TARGET_STRIP ?= xcrun -sdk iphoneos strip
TARGET_STRIP_FLAGS ?= -x
TARGET_CODESIGN_ALLOCATE ?= "$(shell xcrun -sdk iphoneos -find codesign_allocate)"
TARGET_CODESIGN ?= ldid
TARGET_CODESIGN_FLAGS ?= -S

TARGET_PRIVATE_FRAMEWORK_PATH = $(SYSROOT)/System/Library/PrivateFrameworks
TARGET_PRIVATE_FRAMEWORK_INCLUDE_PATH = $(ISYSROOT)/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/targets/_common/darwin.mk
include $(THEOS_MAKE_PATH)/targets/_common/darwin_flat_bundle.mk

ifeq ($(_TARGET_VERSION_GE_7_0),1) # >= 7.0 {
	ARCHS ?= armv7 arm64
else # } < 7.0 {
ifeq ($(_TARGET_VERSION_GE_6_0),1) # >= 6.0 {
ifeq ($(_TARGET_VERSION_GE_7_0)$(_DEPLOY_VERSION_GE_5_0),11) # >= 7.0, Deploy >= 5.0 {
	ARCHS ?= armv7 arm64
else # } else {
	ARCHS ?= armv7
endif # }
else # } < 6.0 {
ifeq ($(_TARGET_VERSION_GE_3_0),1) # >= 3.0 {
	ARCHS ?= armv6 armv7
else # } < 3.0 {
	ARCHS ?= armv6
endif # }
endif # }
endif # }
NEUTRAL_ARCH = armv7

SDKFLAGS := -D__IPHONE_OS_VERSION_MIN_REQUIRED=__IPHONE_$(subst .,_,$(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION))
VERSIONFLAGS := -miphoneos-version-min=$(_THEOS_TARGET_IPHONEOS_DEPLOYMENT_VERSION)
_THEOS_TARGET_CFLAGS := -isysroot "$(ISYSROOT)" $(SDKFLAGS) $(VERSIONFLAGS) $(_THEOS_TARGET_CC_CFLAGS)
_THEOS_TARGET_SWIFTFLAGS := -sdk "$(ISYSROOT)" $(SDKFLAGS) $(_THEOS_TARGET_CC_SWIFTFLAGS)
_THEOS_TARGET_SWIFT_TARGET := apple-ios$(_THEOS_TARGET_SDK_VERSION)
_THEOS_TARGET_SWIFT_LDPATH := $(THEOS_PLATFORM_SDK_ROOT)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos
_THEOS_TARGET_SWIFT_VERSION := $(shell $(TARGET_SWIFT) --version | head -1 | awk '{print $$4}')
_THEOS_TARGET_LDFLAGS := -isysroot "$(SYSROOT)" $(SDKFLAGS) $(VERSIONFLAGS) -multiply_defined suppress

TARGET_INSTALL_REMOTE := $(_THEOS_TRUE)
_THEOS_TARGET_DEFAULT_PACKAGE_FORMAT := deb
endif
