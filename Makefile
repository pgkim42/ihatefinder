APP = IHateFinder.app
BIN = $(APP)/Contents/MacOS

.PHONY: test build run

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
