# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Home Screen quick actions (long-press app icon) for Scan, Create, and Favorites via `UIApplicationShortcutItem` with deep link routing through `barcode-stash://` URL scheme
- Scan barcodes from photo library images via `PhotosPicker` in `HistoryView`
- `ImageBarcodeScanner` service using `VNDetectBarcodesRequest` to detect all 11 supported symbologies from `CGImage` input
- `BarcodeType.init?(symbology:)` initializer mapping `VNBarcodeSymbology` to `BarcodeType`
- EXIF GPS extraction from photo data via `CGImageSource` properties (`kCGImagePropertyGPSDictionary`), detected barcodes inherit the photo's coordinates
- `CIBarcodeDescriptor` archiving from Vision observations for pixel-identical re-rendering of scanned image barcodes
- `ImageScanResultsView` presenting detected barcodes with live preview, payload parsing, duplicate detection against existing SwiftData records, and selectable bulk save
- Multi-image selection support with cross-image deduplication by type + raw value
- `ProgressView` inline loading indicator during image scanning
- Localized strings for image scanning UI across all 10 supported languages
- Share Extension accepting images from the system share sheet, copies images to an app group shared directory and opens the main app to scan them
- `barcode-stash://` custom URL scheme for deep linking from the Share Extension
- App group entitlement (`group.com.alexislours.barcodes-app`) for data sharing between the main app and the Share Extension
- Automatic shared image detection on `scenePhase` change to `.active` as a fallback when the URL scheme callback is missed
- `ImageBarcodeScanner.detectBarcodes(from:)` convenience that downsamples, extracts GPS, and detects in one pass
- `ImageBarcodeScanner.downsampledCGImage(from:maxPixelSize:)` for memory-efficient image loading via `CGImageSourceCreateThumbnailAtIndex`
- Stale file cleanup in the Share Extension shared directory (files older than 1 hour)
- vCard contact preview showing parsed name, phone, and email with interactive `CNContactViewController` for review before saving
- vEvent and vCalendar event preview showing title, dates, and location with `EKEventEditViewController` for review before saving
- In-app SMS composition via `MFMessageComposeViewController` with multi-recipient support
- iPad screenshot automation via `fastlane screenshots_ipad` lane targeting iPad Pro 13-inch (M4)
- Screenshot organize script (`organize_screenshots.sh`) that reorganizes per-locale folders into per-screen folders for App Store Connect upload
- Accessibility identifiers on all four tab bar buttons (`tab-barcodes`, `tab-create`, `tab-map`, `tab-settings`)

### Fixed

- Defer `onSetupComplete` callback in `BarcodeScannerViewController` to avoid modifying SwiftUI state during view update
- `LocationManager` delegate callbacks now use `[weak self]` in MainActor Tasks, fixing non-Sendable `self` capture across isolation boundaries
- Replace `DispatchQueue.main.async` with `Task { @MainActor in }` in `BarcodeScannerViewController` for Swift 6 strict concurrency compliance and add `[weak self]` to camera permission callback
- `metadataOutput` is now captured locally before dispatching to `sessionQueue`, removing the `nonisolated(unsafe)` escape hatch in `BarcodeScannerViewController`
- `CalendarEditDelegate` no longer stores a strong reference to `EKEventEditViewController`, breaking a retain cycle caused by the associated-object back-reference
- SwiftData model is re-fetched after `await` before deletion to prevent crashes when the model is invalidated during an async gap
- File timestamp API usage declared in main app Privacy Manifest (`NSPrivacyAccessedAPICategoryFileTimestamp`)
- Development team set correctly at the project level in build settings
- `descriptorDataSection` no longer calls `descriptorRows()` twice per view evaluation, eliminating redundant `NSKeyedUnarchiver` deserialization
- Share sheet barcode image is now cached in `@State` and generated once in `.task` instead of regenerating
- Barcode preview in detail view now uses `Button` instead of `.onTapGesture`, adding proper VoiceOver button trait, hardware keyboard, and Switch Control support
- Disk cache now enforces a 100 MB size cap with LRU eviction, deleting oldest files when the limit is exceeded
- UPC-E check digit is now validated by expanding to UPC-A and running GS1 Mod-10 verification
- Stats share image is now rendered on demand when the share button is tapped, instead of eagerly on every body evaluation
- Removed redundant `fetchLimit = 0` in `existingBarcode()` that explicitly set the default unlimited fetch value
- `continuousScannedKeys` is now cleared when restarting a bulk scan session, so previously-scanned barcodes can be rescanned after toggling bulk mode
- Search filtering now uses `localizedStandardContains` instead of `localizedCaseInsensitiveContains` for diacritic-insensitive matching (e.g., "cafe" finds "café")
- Tag chip colors are now deterministic across app launches (replaced per-process `hashValue` with stable djb2 hash)
- `CIDataMatrixCodeDescriptor` now receives data-only codewords instead of data+ECC, making the CIFilter descriptor path functional instead of always falling through to the custom renderer
- `ModelContainer` initialization failure no longer crashes the app with `fatalError`; shows a recovery UI with retry and reset options instead
- Database error view now uses localized strings
- Screen brightness is restored after scanner use
- Replaced deprecated `.foregroundColor()` with `.foregroundStyle()` on validation message text in generator view
- `AVCaptureDevice` configuration changes are now guarded by `lockForConfiguration` to prevent crashes
- Double-save race condition in `GeneratorView` prevented
- Reuse a static `CIContext` in `BarcodeGenerator` instead of creating one per render
- Improved performance for swipe actions on barcode rows in `HistoryView`
- Scanner now shows a "Camera Access Required" screen with an "Open Settings" button when camera permission is denied or restricted, instead of a blank view
- Camera permission status is re-checked when the app returns to the foreground, so granting access in Settings immediately updates the scanner
- Scanner close button now has a 44×44pt minimum tap target for accessibility compliance
- Favorites toggle in history filter menu now uses `withAccessibleAnimation` to respect reduced motion preferences
- Filter badge in history filter menu is now hidden from VoiceOver with `accessibilityHidden`
- Tag remove button now has an accessibility label ("Remove \(tag)") for VoiceOver
- `--screenshots` in-memory store flag is now compiled out of release builds via `#if DEBUG`
- `extractVEventBlock` no longer uses cross-string indices from an `uppercased()` copy; uses `.caseInsensitive` search on the original string directly, fixing potential corruption with non-ASCII characters
- vCard and iCal parsing now unfolds RFC 5545 / RFC 6350 continuation lines before splitting, so multi-line properties are read correctly
- Geo URI parser trims whitespace around latitude/longitude values before parsing
- `openPhone` sanitizes phone numbers by stripping non-digit characters (preserving leading `+`) to prevent malformed `tel:` URLs
- `lastModified` in notes field now updates on focus loss or submit instead of every keystroke
- Share extension stale file cleanup no longer blocks the main thread
- `batchDelete()` and `batchTag()` now explicitly save the model context after mutations, preventing deleted barcodes from reappearing or tag changes from being lost if the app terminates before autosave
- Share extension `cleanupStaleFiles` no longer captures `self` in a detached task

### Changed

- Added Privacy Manifest to Share Extension declaring file timestamp API usage
- Added Periphery dead code scanning to CI pipeline and Makefile (`make periphery`)
- `DataMatrixEncoder`: replaced `[any ModeEncoder]` existential array with `AnyModeEncoder` enum for static dispatch; removed `ModeEncoder` protocol
- `DataMatrixEncoder`: removed unnecessary `throws` from `ModeEncoder.encode()` protocol and all 6 implementations; added typed `throws(EncodingError)` to `encodeHighLevel` and `EncoderContext.init`
- Release build: enabled `DEAD_CODE_STRIPPING` and `STRIP_SWIFT_SYMBOLS`; removed stale `NEW_SETTING`
- Redesigned selection mode UI in `HistoryView`
- Migrated project to Swift 6 strict concurrency (`SWIFT_VERSION = 6.0`)
- Redesigned barcode action cards with color-coded icons, structured headers, and per-payload detail rows replacing the single-button layout
- SMS parsing now supports multiple comma-separated recipients and colon-separated `SMSTO:number:message` format
- Calendar event detection also matches `BEGIN:VCALENDAR` wrapper, not just bare `BEGIN:VEVENT`
- Scanner floating action button icon from `plus` to `barcode.viewfinder` in `ContentView`
- Photo library scanning now uses `Data`-based pipeline with downsampling instead of loading full `UIImage` into memory
- Lint and format Makefile targets now include `ShareExtension/` directory
- `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` moved from target-level to project-level build settings
- Screenshot tests use accessibility identifiers for tab navigation instead of index-based lookup, fixing iPad layouts where extra system elements shift button indices
- Fastlane screenshot infrastructure refactored into a shared `run_screenshots` private lane used by both iPhone and iPad pipelines

### Removed

- Wi-Fi network join action (`NEHotspotConfiguration` requires an entitlement unavailable to most apps)
- Debug `print()` calls from app entry point
- Unused `encodingMode` properties on `DataMatrixEncoder` sub-encoders and `AnyModeEncoder.encodingMode` computed property
- Unused `macro05`/`macro06` constants and `SymbolInfo.dataLengthForBlock(_:)` method from `DataMatrixEncoder`
- Unused `deleteBarcodes(at:from:)` method from `HistoryView` batch operations

## [1.0.0] (2026021701) - 2026-02-17

### Added

- Real-time barcode scanning via AVFoundation with bulk mode, torch, and zoom controls
- Barcode generation with three-tier fallback: CIBarcodeDescriptor archive, custom bit-level encoding (EAN-13/8, UPC-E, Code 39/93, ITF-14), and CIFilter (QR, Code 128, PDF417, Aztec)
- Full Data Matrix ECC200 encoder with multi-mode support (ASCII, C40, Text, X12, EDIFACT, Base256) and Reed-Solomon error correction
- Support for 11 barcode formats: QR, EAN-13, EAN-8, UPC-E, Code 128, Code 39, Code 93, PDF417, Aztec, Data Matrix, ITF-14
- Advanced creation options for QR (error correction level), Aztec (layer count), and PDF417 (column count) barcodes
- SwiftData persistence with iCloud sync via CloudKit
- Two-tier image cache (NSCache + disk) for generated barcode images
- Per-format input validation with check digit verification and character set constraints
- QR payload parsing for URLs, phone numbers, email addresses, SMS, WiFi credentials, vCards, calendar events, and geographic coordinates
- MapKit integration with automatic location capture and reverse geocoding
- Favorites, tags, notes, search, and batch operations
- JSON export and import
- Localization for 10 languages: English, German, Spanish, French, Italian, Japanese, Korean, Portuguese (Brazil), Simplified Chinese, Traditional Chinese
- Fastlane screenshot automation with locale-specific mock data
- GitHub repository link in Settings
- Unit tests for BarcodeValidator, BarcodePayloadParser, BarcodeGenerator, DataMatrixEncoder, and ExportableBarcode
- CI workflow with build and test pipeline
