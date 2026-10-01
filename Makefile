PROJECT := Plyst/Plyst.xcodeproj
SCHEME := Plyst
CONFIGURATION ?= Debug
DESTINATION ?= generic/platform=iOS Simulator
TEST_DESTINATION ?= platform=iOS Simulator,id=$(shell xcrun simctl list devices available iPhone | grep -Eo '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | tail -1)
DERIVED_DATA_PATH ?= /tmp/plyst-derived-data
XCODEBUILD_FLAGS ?=

.PHONY: lint build test-build test verify

lint:
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint.yml Plyst/Plyst
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint-tests.yml Plyst/PlystTests

build:
	xcodebuild -quiet $(XCODEBUILD_FLAGS) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		CODE_SIGNING_ALLOWED=NO \
		build

test-build:
	xcodebuild -quiet $(XCODEBUILD_FLAGS) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		CODE_SIGNING_ALLOWED=NO \
		build-for-testing

test:
	xcodebuild $(XCODEBUILD_FLAGS) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(TEST_DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		CODE_SIGNING_ALLOWED=NO \
		test

verify: lint build test-build
