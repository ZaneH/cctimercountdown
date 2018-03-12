ARCHS = armv7 armv7s arm64

TARGET = iphone:clang:latest:8.0

THEOS_BUILD_DIR = Packages

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCTimerCountdown
CCTimerCountdown_CFLAGS = -fobjc-arc
CCTimerCountdown_FILES = CCTimerCountdown.xm
CCTimerCountdown_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 backboardd"
