export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

PROJECT := KremenTransport.xcodeproj
SCHEME  := KremenTransport
BUNDLE  := dev.kremen.transport
SIM     := iPhone 17 Pro
IPAD    := iPad Pro 13-inch (M4)
DD      := build
APP     := $(DD)/Build/Products/Debug-iphonesimulator/KremenTransport.app

.PHONY: gen build test run run-ipad clean lint metadata metadata-push screenshots

gen:
	xcodegen generate --spec project.yml

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
	  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(SIM)' \
	  -derivedDataPath $(DD) CODE_SIGNING_ALLOWED=NO build

test: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	  -destination 'platform=iOS Simulator,name=$(SIM)' \
	  -derivedDataPath $(DD) CODE_SIGNING_ALLOWED=NO test

run: build
	xcrun simctl boot "$(SIM)" || true
	open -a Simulator
	xcrun simctl install booted "$(APP)"
	xcrun simctl launch booted $(BUNDLE)

run-ipad: build
	xcrun simctl boot "$(IPAD)" || true
	open -a Simulator
	xcrun simctl install "$(IPAD)" "$(APP)"
	xcrun simctl launch "$(IPAD)" $(BUNDLE)

clean:
	rm -rf $(DD) $(PROJECT) App/Supporting/Info.plist

# App Store listing text, mirrored into fastlane/metadata (see fastlane/Fastfile)
metadata:
	fastlane metadata_pull

metadata-push:
	fastlane metadata_push

screenshots:
	fastlane screenshots_pull
