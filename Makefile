PROJECT := Plyst/Plyst.xcodeproj
SCHEME := Plyst
CONFIGURATION ?= Debug
DESTINATION ?= generic/platform=iOS Simulator
DERIVED_DATA_PATH ?= /tmp/plyst-derived-data

.PHONY: lint build test-build verify

lint:
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint.yml Plyst/Plyst
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint-tests.yml Plyst/PlystTests

build:
	xcodebuild -quiet \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		CODE_SIGNING_ALLOWED=NO \
		build

test-build:
	xcodebuild -quiet \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		CODE_SIGNING_ALLOWED=NO \
		build-for-testing

verify: lint build test-build
