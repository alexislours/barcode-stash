.PHONY: lint lint-fix format format-check build test test-ci periphery

lint:
	swiftlint lint barcodes/ ShareExtension/

lint-fix:
	swiftlint lint --fix barcodes/ ShareExtension/

format:
	swiftformat barcodes/ ShareExtension/

format-check:
	swiftformat --lint barcodes/ ShareExtension/

build:
	xcodebuild build-for-testing -project barcodes.xcodeproj -scheme barcodes \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | xcbeautify

test:
	rm -rf .build/tests.xcresult
	xcodebuild test -project barcodes.xcodeproj -scheme barcodes \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		-only-testing:barcodesTests \
		-resultBundlePath .build/tests.xcresult 2>&1 | xcbeautify --quiet
	@xcrun xcresulttool get test-results summary --path .build/tests.xcresult --compact \
		| jq -r '"", "  \(.result) — \(.passedTests) passed, \(.failedTests) failed, \(.skippedTests) skipped (\(.totalTestCount) total)", (if (.testFailures | length) > 0 then "  Failures:", (.testFailures[] | "    ✗ \(.testName): \(.message)") else empty end), ""'

test-ci:
	xcodebuild test -project barcodes.xcodeproj -scheme barcodes \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		-only-testing:barcodesTests 2>&1 | xcbeautify --renderer github-actions

periphery:
	periphery scan
