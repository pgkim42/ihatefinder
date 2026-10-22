APP = IHateFinder.app
BIN = $(APP)/Contents/MacOS

DIST = dist
RELEASE_APP = $(DIST)/$(APP)
RELEASE_FLAGS = -c release --arch arm64 --arch x86_64
VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
BUILD ?= 1
DMG = $(DIST)/IHateFinder-$(VERSION).dmg

.PHONY: test build run release-app dmg

test:
	swift test

build:
	swift build
	rm -rf $(APP)
	mkdir -p $(BIN)
	cp .build/debug/IHateFinder $(BIN)/IHateFinder
	cp Support/Info.plist $(APP)/Contents/Info.plist
	codesign --force --deep --sign - $(APP)

run: build
	open $(APP)

# Universal (Apple Silicon + Intel) build with an ad-hoc signature.
release-app:
	swift build $(RELEASE_FLAGS)
	rm -rf $(RELEASE_APP)
	mkdir -p $(RELEASE_APP)/Contents/MacOS
	cp "$$(swift build $(RELEASE_FLAGS) --show-bin-path)/IHateFinder" $(RELEASE_APP)/Contents/MacOS/IHateFinder
	cp Support/Info.plist $(RELEASE_APP)/Contents/Info.plist
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $(RELEASE_APP)/Contents/Info.plist
	plutil -replace CFBundleVersion -string "$(BUILD)" $(RELEASE_APP)/Contents/Info.plist
	codesign --force --deep --sign - $(RELEASE_APP)

dmg: release-app
	rm -rf $(DIST)/dmg $(DMG)
	mkdir -p $(DIST)/dmg
	ditto $(RELEASE_APP) $(DIST)/dmg/$(APP)
	ln -s /Applications $(DIST)/dmg/Applications
	hdiutil create -volname IHateFinder -srcfolder $(DIST)/dmg -fs HFS+ -format UDZO -ov $(DMG)
	rm -rf $(DIST)/dmg
