APP_BUNDLE := .build/MouseLocator.app

.PHONY: build test app run clean

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

run: app
	open $(APP_BUNDLE)

clean:
	swift package clean
