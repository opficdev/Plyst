PROJECT := Plyst/Plyst.xcodeproj
SCHEME := Plyst
CONFIGURATION ?= Debug
DESTINATION ?= generic/platform=iOS Simulator
TEST_DEVICE_ID ?= $(shell xcrun simctl list devices available iPhone | grep -Eo '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | tail -1)
TEST_DESTINATION ?= platform=iOS Simulator,id=$(TEST_DEVICE_ID)
RESULT_BUNDLE_PATH ?= /tmp/plyst-test-results.xcresult
TEST_FLAGS ?= -test-timeouts-enabled YES \
	-default-test-execution-time-allowance 60 \
	-maximum-test-execution-time-allowance 120
DERIVED_DATA_PATH ?= /tmp/plyst-derived-data
XCODEBUILD_FLAGS ?=
XCTESTRUN ?= $(firstword $(wildcard $(DERIVED_DATA_PATH)/Build/Products/*.xctestrun))
MATCH_FORCE ?= false

.PHONY: lint build test-build test-device-id test-without-building test-prebuilt test verify deploy-setup deploy-check testflight-build testflight appstore-build appstore signing-sync

lint:
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint.yml Plyst/Plyst
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint.yml Plyst/Common
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint.yml Plyst/ShareExtension
	mise exec -- swiftlint lint --strict --no-cache --config .swiftlint.yml Plyst/WidgetExtension
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

test-device-id:
	@echo "$(TEST_DEVICE_ID)"

test-without-building:
	rm -rf "$(RESULT_BUNDLE_PATH)"
	xcodebuild $(XCODEBUILD_FLAGS) $(TEST_FLAGS) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "$(TEST_DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		-resultBundlePath "$(RESULT_BUNDLE_PATH)" \
		CODE_SIGNING_ALLOWED=NO \
		test-without-building

test-prebuilt:
	rm -rf "$(RESULT_BUNDLE_PATH)"
	xcodebuild $(XCODEBUILD_FLAGS) $(TEST_FLAGS) \
		-xctestrun "$(XCTESTRUN)" \
		-destination "$(TEST_DESTINATION)" \
		-resultBundlePath "$(RESULT_BUNDLE_PATH)" \
		test-without-building

test:
	$(MAKE) test-build DESTINATION="$(TEST_DESTINATION)"
	$(MAKE) test-without-building

verify: lint build test-build

deploy-setup:
	bundle config set --local path vendor/bundle
	bundle install
	test -f fastlane/secrets.json || cp fastlane/secrets.example.json fastlane/secrets.json

deploy-check:
	scripts/deploy-local.sh check

testflight-build:
	scripts/deploy-local.sh testflight_build_only

testflight:
	scripts/deploy-local.sh deploy_testflight

appstore-build:
	scripts/deploy-local.sh appstore_build_only

appstore:
	scripts/deploy-local.sh deploy_appstore

signing-sync:
	MATCH_FORCE="$(MATCH_FORCE)" scripts/deploy-local.sh sync_appstore_profiles
