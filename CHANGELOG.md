# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
