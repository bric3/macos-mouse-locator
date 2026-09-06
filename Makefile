APP_BUNDLE := .build/MouseLocator.app
INSTALL_DIR ?= $(HOME)/Applications
INSTALLED_APP := $(INSTALL_DIR)/MouseLocator.app

.PHONY: build test app install run clean

build:
	swift build

test:
	swift run MouseLocatorCheck

app:
	swift build -c release
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp .build/release/MouseLocator $(APP_BUNDLE)/Contents/MacOS/MouseLocator
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(APP_BUNDLE)

install: app
	mkdir -p "$(INSTALL_DIR)"
	-@pkill -f "^$(INSTALLED_APP)/Contents/MacOS/MouseLocator$$" 2>/dev/null
	ditto "$(APP_BUNDLE)" "$(INSTALLED_APP)"
	codesign --force --sign - "$(INSTALLED_APP)"
	open "$(INSTALLED_APP)"

run: app
	open $(APP_BUNDLE)

clean:
	swift package clean
