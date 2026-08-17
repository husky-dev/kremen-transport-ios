export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

PROJECT := KremenTransport.xcodeproj
SCHEME  := KremenTransport
BUNDLE  := dev.kremen.transport
SIM     := iPhone 17 Pro
DD      := build
APP     := $(DD)/Build/Products/Debug-iphonesimulator/KremenTransport.app

.PHONY: gen build test run clean lint

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

clean:
	rm -rf $(DD) $(PROJECT) App/Supporting/Info.plist
