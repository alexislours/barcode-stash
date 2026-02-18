import XCTest

final class ScreenshotTests: XCTestCase {
    nonisolated(unsafe) var app: XCUIApplication!

    /// Localized search terms for the search screenshot.
    /// Must match the "grocery" tag translation in MockDataSeeder's locale map.
    private static let searchTerms: [String: String] = [
        "en-US": "grocery",
        "de-DE": "Einkauf",
        "es-ES": "supermercado",
        "fr-FR": "courses",
        "it": "spesa",
        "ja": "食料品",
        "ko": "식료품",
        "pt-BR": "mercado",
        "zh-Hans": "食品",
        "zh-Hant": "食品",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
    }

    // MARK: - Per-Language Test Entry Points

    func testScreenshots_EnUS()   { runScreenshots(language: "en-US",    locale: "en_US") }
    func testScreenshots_DeDE()   { runScreenshots(language: "de-DE",    locale: "de_DE") }
    func testScreenshots_EsES()   { runScreenshots(language: "es-ES",    locale: "es_ES") }
    func testScreenshots_FrFR()   { runScreenshots(language: "fr-FR",    locale: "fr_FR") }
    func testScreenshots_It()     { runScreenshots(language: "it",       locale: "it") }
    func testScreenshots_Ja()     { runScreenshots(language: "ja",       locale: "ja") }
    func testScreenshots_Ko()     { runScreenshots(language: "ko",       locale: "ko") }
    func testScreenshots_PtBR()   { runScreenshots(language: "pt-BR",    locale: "pt_BR") }
    func testScreenshots_ZhHans() { runScreenshots(language: "zh-Hans",  locale: "zh_Hans") }
    func testScreenshots_ZhHant() { runScreenshots(language: "zh-Hant",  locale: "zh_Hant") }

    // MARK: - Shared Runner

    private func runScreenshots(language: String, locale: String) {
        MainActor.assumeIsolated {
            Snapshot.deviceLanguage = language
            Snapshot.currentLocale = locale
        }

        app.launchArguments = [
            "--screenshots",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-FASTLANE_SNAPSHOT", "YES",
            "-ui_testing",
        ]
        if let bgPath = Bundle(for: Self.self).path(forResource: "bg", ofType: "jpg") {
            app.launchArguments.append("--screenshot-bg=\(bgPath)")
        }

        XCUIDevice.shared.appearance = .light
        app.launch()

        captureScreenshots(language: language)
    }

    // MARK: - Screenshot Flow

    private func step(_ name: String, action: () -> Void) {
        XCTContext.runActivity(named: name) { _ in action() }
    }

    private func captureScreenshots(language: String) {
        captureHistoryScreenshots(language: language)
        captureGeneratorScreenshots()
        captureMapAndScannerScreenshots()
    }

    // MARK: - History Tab

    private func captureHistoryScreenshots(language: String) {
        step("01-History") {
            let historyList = app.collectionViews.firstMatch
            XCTAssertTrue(historyList.waitForExistence(timeout: 10))
            snapshot("01-History")
        }

        step("10-Stats") {
            let statsButton = app.buttons["statistics-button"]
            XCTAssertTrue(statsButton.waitForExistence(timeout: 5))
            statsButton.tap()

            let statsList = app.collectionViews["stats-list"]
            XCTAssertTrue(statsList.waitForExistence(timeout: 5))
            snapshot("10-Stats")

            // Back to History
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        step("02-WiFi-Detail") {
            // Accessibility identifier based on rawValue (locale-independent)
            let wifiRow = app.buttons["barcode-row-WIFI:T:WPA;S:CafeWifi;P:welcome2024;;"]
            XCTAssertTrue(wifiRow.waitForExistence(timeout: 5))
            wifiRow.tap()

            let joinWifi = app.buttons["payload-action-button"]
            XCTAssertTrue(joinWifi.waitForExistence(timeout: 5))
            snapshot("02-WiFi-Detail")
        }

        step("08-Share") {
            let shareButton = app.buttons["share-barcode-button"]
            XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
            shareButton.tap()

            // Select "Card" mode - second segment in the picker
            let segmentedPicker = app.segmentedControls.firstMatch
            XCTAssertTrue(segmentedPicker.waitForExistence(timeout: 5))
            segmentedPicker.buttons.element(boundBy: 1).tap()
            sleep(3) // Wait for map snapshot to load
            snapshot("08-Share")

            // Dismiss share sheet
            let doneButton = app.buttons["share-done-button"]
            XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
            doneButton.tap()

            // Back to History from WiFi detail
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        step("07-Notes-Tags") {
            // Accessibility identifier based on rawValue (locale-independent)
            let pencilRow = app.buttons["barcode-row-4006381333931"]
            XCTAssertTrue(pencilRow.waitForExistence(timeout: 5))
            pencilRow.tap()

            let addTag = app.buttons["add-tag-button"]
            XCTAssertTrue(addTag.waitForExistence(timeout: 5))
            snapshot("07-Notes-Tags")

            // Back to History
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        step("09-Search (\(Self.searchTerms[language] ?? "grocery"))") {
            // Swipe down on the list to reveal the search bar
            let list = app.collectionViews.firstMatch
            XCTAssertTrue(list.waitForExistence(timeout: 5))
            list.swipeDown()

            let searchField = app.searchFields.firstMatch
            XCTAssertTrue(searchField.waitForExistence(timeout: 5))
            searchField.tap()
            let searchTerm = Self.searchTerms[language] ?? "grocery"
            searchField.typeText(searchTerm)
            sleep(1)
            snapshot("09-Search")

            // Dismiss search - the cancel/close button is the only nav bar button when search is active
            let cancelSearch = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(cancelSearch.waitForExistence(timeout: 3))
            cancelSearch.tap()
        }
    }

    // MARK: - Generator Tab

    private func captureGeneratorScreenshots() {
        step("03-Generator-QR") {
            // Navigate to Create tab (index 1) - avoids localized tab label
            app.tabBars.buttons.element(boundBy: 1).tap()

            // QR is the default type - type a URL into the TextEditor
            let textEditor = app.textViews["barcode-input-editor"]
            XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
            textEditor.tap()
            textEditor.typeText("https://example.com/my-page")
            sleep(2) // Wait for preview generation
            // Dismiss keyboard by swiping down on the form
            app.swipeDown()
            sleep(1)
            snapshot("03-Generator-QR")
        }

        step("06-Generator-EAN13") {
            // Change type to EAN-13 via the menu picker
            let typePicker = app.buttons["barcode-type-picker"]
            XCTAssertTrue(typePicker.waitForExistence(timeout: 5))
            typePicker.tap()

            // Barcode type names are technical and not translated
            let ean13Option = app.buttons["EAN-13"]
            if !ean13Option.waitForExistence(timeout: 3) {
                app.staticTexts["EAN-13"].tap()
            } else {
                ean13Option.tap()
            }

            let textField = app.textFields["barcode-input-field"]
            XCTAssertTrue(textField.waitForExistence(timeout: 5))
            textField.tap()
            textField.typeText("5901234123457")
            sleep(2) // Wait for preview generation
            app.swipeDown()
            sleep(1)
            snapshot("06-Generator-EAN13")
        }
    }

    // MARK: - Map & Scanner

    private func captureMapAndScannerScreenshots() {
        step("04-Map") {
            // Navigate to Map tab (index 2)
            app.tabBars.buttons.element(boundBy: 2).tap()
            sleep(3) // Wait for map tiles to load
            snapshot("04-Map")
        }

        step("05-Scanner") {
            // Navigate to Barcodes tab (index 0)
            app.tabBars.buttons.element(boundBy: 0).tap()

            let scanButton = app.buttons["scan-barcode-button"]
            XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
            scanButton.tap()

            let saveButton = app.buttons["save-barcode-button"]
            XCTAssertTrue(saveButton.waitForExistence(timeout: 10))
            snapshot("05-Scanner")
        }
    }
}
