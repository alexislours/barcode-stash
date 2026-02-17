import Foundation
import Testing
@testable import barcodes

// MARK: - Codable Round-Trip

@Suite("Codable Round-Trip")
struct ExportableBarcodeCodableTests {
    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func roundTrip(_ original: ExportableBarcode) throws -> ExportableBarcode {
        let data = try Self.encoder.encode(original)
        return try Self.decoder.decode(ExportableBarcode.self, from: data)
    }

    @Test("All fields survive encode → decode")
    func fullRoundTrip() throws {
        let lastMod = Self.fixedDate.addingTimeInterval(500)
        let barcode = ScannedBarcode(
            rawValue: "4006381333931",
            type: .ean13,
            latitude: 48.8566,
            longitude: 2.3522,
            descriptorArchive: Data([0xDE, 0xAD]),
            barcodeDescription: "Test barcode",
            timestamp: Self.fixedDate,
            isFavorite: true,
            tags: ["groceries", "imported"],
            address: "Paris, France",
            isGenerated: true,
            lastModified: lastMod,
            correctionLevel: "M",
            isCompactStyle: true,
            compactionMode: "automatic",
            columnCount: 4
        )
        let original = ExportableBarcode(from: barcode)
        let decoded = try roundTrip(original)

        #expect(decoded.rawValue == "4006381333931")
        #expect(decoded.type == "EAN-13")
        #expect(decoded.latitude == 48.8566)
        #expect(decoded.longitude == 2.3522)
        #expect(decoded.descriptorArchive == Data([0xDE, 0xAD]))
        #expect(decoded.barcodeDescription == "Test barcode")
        #expect(decoded.timestamp == Self.fixedDate)
        #expect(decoded.isFavorite == true)
        #expect(decoded.tags == ["groceries", "imported"])
        #expect(decoded.address == "Paris, France")
        #expect(decoded.isGenerated == true)
        #expect(decoded.lastModified == lastMod)
        #expect(decoded.correctionLevel == "M")
        #expect(decoded.isCompactStyle == true)
        #expect(decoded.compactionMode == "automatic")
        #expect(decoded.columnCount == 4)
    }

    @Test("Minimal barcode (defaults from ScannedBarcode)")
    func minimalRoundTrip() throws {
        let barcode = ScannedBarcode(
            rawValue: "https://example.com",
            type: .qr,
            timestamp: Self.fixedDate
        )
        let original = ExportableBarcode(from: barcode)
        let decoded = try roundTrip(original)

        #expect(decoded.rawValue == "https://example.com")
        #expect(decoded.type == "QR")
        #expect(decoded.latitude == nil)
        #expect(decoded.longitude == nil)
        #expect(decoded.descriptorArchive == nil)
        #expect(decoded.barcodeDescription == nil)
        #expect(decoded.timestamp == Self.fixedDate)
        #expect(decoded.isFavorite == false)
        #expect(decoded.tags == [])
        #expect(decoded.address == nil)
        #expect(decoded.isGenerated == false)
        #expect(decoded.lastModified == nil)
        #expect(decoded.correctionLevel == nil)
        // ScannedBarcode defaults isCompactStyle to false, so round-trip
        // preserves Optional(false) rather than nil
        #expect(decoded.isCompactStyle == false)
        #expect(decoded.compactionMode == nil)
        #expect(decoded.columnCount == nil)

    }

    @Test("Every BarcodeType raw value round-trips", arguments: BarcodeType.allCases)
    func typeRoundTrips(type: BarcodeType) throws {
        let barcode = ScannedBarcode(
            rawValue: "test",
            type: type,
            timestamp: Self.fixedDate
        )
        let decoded = try roundTrip(ExportableBarcode(from: barcode))
        #expect(decoded.type == type.rawValue)
    }

    @Test("Unicode content in rawValue and tags")
    func unicodeContent() throws {
        let barcode = ScannedBarcode(
            rawValue: "日本語テスト 🇯🇵",
            type: .qr,
            timestamp: Self.fixedDate,
            tags: ["タグ", "étiquette"]
        )
        let decoded = try roundTrip(ExportableBarcode(from: barcode))
        #expect(decoded.rawValue == "日本語テスト 🇯🇵")
        #expect(decoded.tags == ["タグ", "étiquette"])
    }

    @Test("Array encoding produces valid JSON array")
    func arrayRoundTrip() throws {
        let barcodes = [
            ScannedBarcode(rawValue: "A", type: .qr, timestamp: Self.fixedDate),
            ScannedBarcode(rawValue: "B", type: .ean13, timestamp: Self.fixedDate),
        ]
        let exportable = barcodes.map(ExportableBarcode.init)
        let data = try Self.encoder.encode(exportable)
        let decoded = try Self.decoder.decode([ExportableBarcode].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].rawValue == "A")
        #expect(decoded[1].rawValue == "B")
    }
}

// MARK: - CSV Export

@Suite("CSV Export")
struct ExportableBarcodeCSVTests {
    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func csvLines(from barcodes: [ScannedBarcode]) throws -> [String] {
        let url = try ExportableBarcode.exportToFile(barcodes, format: .csv)
        let csv = try String(contentsOf: url, encoding: .utf8)
        return csv.components(separatedBy: "\r\n")
    }

    @Test("Header row contains all expected columns")
    func headerRow() throws {
        let barcodes = [ScannedBarcode(rawValue: "test", type: .qr, timestamp: Self.fixedDate)]
        let lines = try csvLines(from: barcodes)
        let expected = [
            "rawValue", "type", "latitude", "longitude", "barcodeDescription",
            "timestamp", "isFavorite", "tags", "address", "isGenerated",
            "lastModified", "correctionLevel", "isCompactStyle", "compactionMode", "columnCount",
        ]
        #expect(lines[0] == expected.joined(separator: ","))
    }

    @Test("descriptorArchive is excluded from CSV")
    func descriptorArchiveExcluded() throws {
        let barcode = ScannedBarcode(
            rawValue: "test", type: .qr,
            descriptorArchive: Data([0xDE, 0xAD]),
            timestamp: Self.fixedDate
        )
        let lines = try csvLines(from: [barcode])
        #expect(!lines[0].contains("descriptorArchive"))
    }

    @Test("Tags joined with pipe separator")
    func tagsJoinedWithPipe() throws {
        let barcode = ScannedBarcode(
            rawValue: "test", type: .qr,
            timestamp: Self.fixedDate,
            tags: ["groceries", "imported"]
        )
        let lines = try csvLines(from: [barcode])
        #expect(lines[1].contains("groceries|imported"))
    }

    @Test("Dates use ISO 8601 format")
    func iso8601Dates() throws {
        let barcode = ScannedBarcode(
            rawValue: "test", type: .qr,
            timestamp: Self.fixedDate
        )
        let lines = try csvLines(from: [barcode])
        let expectedDate = Self.iso8601Formatter.string(from: Self.fixedDate)
        #expect(lines[1].contains(expectedDate))
    }

    @Test("Fields with commas are quoted")
    func commasEscaped() throws {
        let barcode = ScannedBarcode(
            rawValue: "hello, world", type: .qr,
            timestamp: Self.fixedDate
        )
        let lines = try csvLines(from: [barcode])
        #expect(lines[1].hasPrefix("\"hello, world\""))
    }

    @Test("Fields with double quotes are escaped")
    func doubleQuotesEscaped() throws {
        let barcode = ScannedBarcode(
            rawValue: "say \"hello\"", type: .qr,
            timestamp: Self.fixedDate
        )
        let lines = try csvLines(from: [barcode])
        #expect(lines[1].contains("\"say \"\"hello\"\"\""))
    }

    @Test("Fields with newlines are quoted")
    func newlinesEscaped() throws {
        let barcode = ScannedBarcode(
            rawValue: "line1\nline2", type: .qr,
            timestamp: Self.fixedDate
        )
        let url = try ExportableBarcode.exportToFile([barcode], format: .csv)
        let csv = try String(contentsOf: url, encoding: .utf8)
        #expect(csv.contains("\"line1\nline2\""))
    }

    @Test("Nil optional fields produce empty cells")
    func nilFieldsEmpty() throws {
        let barcode = ScannedBarcode(
            rawValue: "test", type: .qr,
            timestamp: Self.fixedDate
        )
        let lines = try csvLines(from: [barcode])
        // latitude and longitude (columns 3-4) should be empty
        let fields = lines[1].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(fields[2] == "")  // latitude
        #expect(fields[3] == "")  // longitude
    }

    @Test("Multiple barcodes produce correct row count")
    func multipleRows() throws {
        let barcodes = [
            ScannedBarcode(rawValue: "A", type: .qr, timestamp: Self.fixedDate),
            ScannedBarcode(rawValue: "B", type: .ean13, timestamp: Self.fixedDate),
            ScannedBarcode(rawValue: "C", type: .code128, timestamp: Self.fixedDate),
        ]
        let lines = try csvLines(from: barcodes)
        // header + 3 data rows (no trailing empty line since we split on \r\n)
        #expect(lines.count == 4)
    }

    @Test("JSON format still works with new signature")
    func jsonFormatStillWorks() throws {
        let barcode = ScannedBarcode(
            rawValue: "test", type: .qr,
            timestamp: Self.fixedDate
        )
        let url = try ExportableBarcode.exportToFile([barcode], format: .json)
        #expect(url.pathExtension == "json")
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ExportableBarcode].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].rawValue == "test")
    }
}

// MARK: - Backward-Compatible Decoding

@Suite("Backward-Compatible Decoding")
struct ExportableBarcodeBackwardCompatTests {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("JSON missing optional fields decodes with nils")
    func missingOptionalFields() throws {
        let json = """
        {
            "rawValue": "12345678",
            "type": "EAN-8",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": false,
            "isGenerated": false
        }
        """
        let decoded = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        #expect(decoded.rawValue == "12345678")
        #expect(decoded.type == "EAN-8")
        #expect(decoded.latitude == nil)
        #expect(decoded.longitude == nil)
        #expect(decoded.descriptorArchive == nil)
        #expect(decoded.barcodeDescription == nil)
        #expect(decoded.tags == nil)
        #expect(decoded.address == nil)
        #expect(decoded.lastModified == nil)
        #expect(decoded.correctionLevel == nil)
        #expect(decoded.isCompactStyle == nil)
        #expect(decoded.compactionMode == nil)
        #expect(decoded.columnCount == nil)

    }

    @Test("JSON with only advanced options populated")
    func advancedOptionsOnly() throws {
        let json = """
        {
            "rawValue": "Hello",
            "type": "PDF417",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": false,
            "isGenerated": true,
            "correctionLevel": "2",
            "compactionMode": "automatic",
            "columnCount": 6
        }
        """
        let decoded = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        #expect(decoded.correctionLevel == "2")
        #expect(decoded.compactionMode == "automatic")
        #expect(decoded.columnCount == 6)
        #expect(decoded.isCompactStyle == nil)
    }

    @Test("Extra unknown keys in JSON are silently ignored")
    func unknownKeysIgnored() throws {
        let json = """
        {
            "rawValue": "test",
            "type": "QR",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": false,
            "isGenerated": false,
            "futureField": "should be ignored",
            "anotherFuture": 42
        }
        """
        let decoded = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        #expect(decoded.rawValue == "test")
    }
}

// MARK: - toScannedBarcode Conversion

@Suite("toScannedBarcode Conversion")
struct ExportableBarcodeConversionTests {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("Valid type string converts successfully")
    func validTypeConverts() throws {
        let json = """
        {
            "rawValue": "https://example.com",
            "type": "QR",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": true,
            "isGenerated": false,
            "tags": ["web"],
            "address": "Home"
        }
        """
        let exportable = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        let barcode = exportable.toScannedBarcode()

        #expect(barcode != nil)
        #expect(barcode?.rawValue == "https://example.com")
        #expect(barcode?.type == .qr)
        #expect(barcode?.isFavorite == true)
        #expect(barcode?.tags == ["web"])
        #expect(barcode?.address == "Home")
    }

    @Test("Unknown type string returns nil")
    func unknownTypeReturnsNil() throws {
        let json = """
        {
            "rawValue": "test",
            "type": "UnknownFormat",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": false,
            "isGenerated": false
        }
        """
        let exportable = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        #expect(exportable.toScannedBarcode() == nil)
    }

    @Test("Nil tags default to empty array in ScannedBarcode")
    func nilTagsDefaultToEmpty() throws {
        let json = """
        {
            "rawValue": "test",
            "type": "QR",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": false,
            "isGenerated": false
        }
        """
        let exportable = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        let barcode = exportable.toScannedBarcode()
        #expect(barcode?.tags == [])
    }

    @Test("Nil isCompactStyle defaults to false in ScannedBarcode")
    func nilCompactStyleDefaultsToFalse() throws {
        let json = """
        {
            "rawValue": "test",
            "type": "Aztec",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": false,
            "isGenerated": true
        }
        """
        let exportable = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        let barcode = exportable.toScannedBarcode()
        #expect(barcode?.isCompactStyle == false)
    }

    @Test("All BarcodeType values convert back", arguments: BarcodeType.allCases)
    func allTypesConvertBack(type: BarcodeType) throws {
        let json = """
        {
            "rawValue": "test",
            "type": "\(type.rawValue)",
            "timestamp": "2023-11-14T22:13:20Z",
            "isFavorite": false,
            "isGenerated": false
        }
        """
        let exportable = try Self.decoder.decode(
            ExportableBarcode.self, from: Data(json.utf8)
        )
        let barcode = exportable.toScannedBarcode()
        #expect(barcode?.type == type)
    }

}
