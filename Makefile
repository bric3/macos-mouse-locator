APP_BUNDLE := .build/MouseLocator.app
PREFPANE_BUNDLE := .build/MouseLocator.prefPane
INSTALL_DIR ?= $(HOME)/Applications
PREFPANE_INSTALL_DIR ?= $(HOME)/Library/PreferencePanes
INSTALLED_APP := $(INSTALL_DIR)/MouseLocator.app
INSTALLED_PREFPANE := $(PREFPANE_INSTALL_DIR)/MouseLocator.prefPane
SWIFT_TARGET := $(shell uname -m)-apple-macosx14.0

.PHONY: build test release app prefpane screenshots install uninstall run clean

build:
	swift build

test:
	swift run MouseLocatorCheck

release:
	swift build -c release

app: release
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp .build/release/MouseLocator $(APP_BUNDLE)/Contents/MacOS/MouseLocator
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(APP_BUNDLE)

prefpane: release
	mkdir -p $(PREFPANE_BUNDLE)/Contents/MacOS $(PREFPANE_BUNDLE)/Contents/Resources
	swiftc -emit-library -parse-as-library -swift-version 6 -target $(SWIFT_TARGET) \
		-module-name MouseLocatorPreferencePane \
		-I .build/release/Modules \
		Sources/MouseLocator/SettingsView.swift \
		Sources/MouseLocatorPreferencePane/MouseLocatorPreferencePane.swift \
		.build/release/MouseLocatorCore.build/EffectTiming.swift.o \
		-framework AppKit -framework PreferencePanes -framework SwiftUI \
		-o $(PREFPANE_BUNDLE)/Contents/MacOS/MouseLocatorPreferences
	cp Resources/PreferencePane-Info.plist $(PREFPANE_BUNDLE)/Contents/Info.plist
	cp Resources/MouseLocator.icns $(PREFPANE_BUNDLE)/Contents/Resources/MouseLocator.icns
	codesign --force --sign - $(PREFPANE_BUNDLE)

screenshots: app
	jbang scripts/CaptureShowcases.java

install: app prefpane
	mkdir -p "$(INSTALL_DIR)"
	mkdir -p "$(PREFPANE_INSTALL_DIR)"
	-@pkill -f "^$(INSTALLED_APP)/Contents/MacOS/MouseLocator( |$$)" 2>/dev/null
	ditto "$(APP_BUNDLE)" "$(INSTALLED_APP)"
	codesign --force --sign - "$(INSTALLED_APP)"
	ditto "$(PREFPANE_BUNDLE)" "$(INSTALLED_PREFPANE)"
	codesign --force --sign - "$(INSTALLED_PREFPANE)"
	touch "$(PREFPANE_INSTALL_DIR)"
	open -n "$(INSTALLED_APP)" --args --register-login

uninstall:
	-@pkill -f "^$(INSTALLED_APP)/Contents/MacOS/MouseLocator( |$$)" 2>/dev/null
	-@open -W -n "$(INSTALLED_APP)" --args --unregister-login 2>/dev/null
	rm -rf "$(INSTALLED_APP)" "$(INSTALLED_PREFPANE)"

run: app
	open $(APP_BUNDLE)

clean:
	swift package clean
