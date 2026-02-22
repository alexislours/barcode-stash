import Foundation
import SwiftData

enum ExportFormat {
    case json
    case csv
}

struct ExportableBarcode: Codable {
    var rawValue: String
    var type: String
    var latitude: Double?
    var longitude: Double?
    var descriptorArchive: Data?
    var barcodeDescription: String?
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]?
    var address: String?
    var isGenerated: Bool
    var lastModified: Date?
    var correctionLevel: String?
    // swiftlint:disable:next discouraged_optional_boolean
    var isCompactStyle: Bool?
    var compactionMode: String?
    var columnCount: Int?
    @MainActor init(from barcode: ScannedBarcode) {
        rawValue = barcode.rawValue
        type = barcode.type.rawValue
        latitude = barcode.latitude
        longitude = barcode.longitude
        descriptorArchive = barcode.descriptorArchive
        barcodeDescription = barcode.barcodeDescription
        timestamp = barcode.timestamp
        isFavorite = barcode.isFavorite
        tags = barcode.tags
        address = barcode.address
        isGenerated = barcode.isGenerated
        lastModified = barcode.lastModified == .distantPast ? nil : barcode.lastModified
        correctionLevel = barcode.correctionLevel
        isCompactStyle = barcode.isCompactStyle
        compactionMode = barcode.compactionMode
        columnCount = barcode.columnCount
    }

    static func exportToFile(_ barcodes: [ScannedBarcode], format: ExportFormat = .json) throws -> URL {
        let exportable = barcodes.map(ExportableBarcode.init)

        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(exportable)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("barcodes-export.json")
            try data.write(to: url)
            return url

        case .csv:
            let csv = buildCSV(from: exportable)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("barcodes-export.csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    // MARK: - CSV Helpers

    private static let csvColumns = [
        "rawValue", "type", "latitude", "longitude", "barcodeDescription",
        "timestamp", "isFavorite", "tags", "address", "isGenerated",
        "lastModified", "correctionLevel", "isCompactStyle", "compactionMode", "columnCount",
    ]

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func buildCSV(from barcodes: [ExportableBarcode]) -> String {
        var lines: [String] = []
        lines.append(csvColumns.joined(separator: ","))

        for barcode in barcodes {
            var fields: [String] = []
            fields.append(escapeCSVField(barcode.rawValue))
            fields.append(escapeCSVField(barcode.type))
            fields.append(barcode.latitude.map { String($0) } ?? "")
            fields.append(barcode.longitude.map { String($0) } ?? "")
            fields.append(escapeCSVField(barcode.barcodeDescription ?? ""))
            fields.append(escapeCSVField(iso8601Formatter.string(from: barcode.timestamp)))
            fields.append(String(barcode.isFavorite))
            fields.append(escapeCSVField(barcode.tags?.joined(separator: "|") ?? ""))
            fields.append(escapeCSVField(barcode.address ?? ""))
            fields.append(String(barcode.isGenerated))
            fields.append(barcode.lastModified.map { escapeCSVField(iso8601Formatter.string(from: $0)) } ?? "")
            fields.append(escapeCSVField(barcode.correctionLevel ?? ""))
            fields.append(barcode.isCompactStyle.map { String($0) } ?? "")
            fields.append(escapeCSVField(barcode.compactionMode ?? ""))
            fields.append(barcode.columnCount.map { String($0) } ?? "")
            lines.append(fields.joined(separator: ","))
        }

        return lines.joined(separator: "\r\n")
    }

    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    nonisolated func toScannedBarcode() -> ScannedBarcode? {
        guard let barcodeType = BarcodeType.allCases.first(where: { $0.rawValue == type }) else {
            return nil
        }
        return ScannedBarcode(
            rawValue: rawValue,
            type: barcodeType,
            latitude: latitude,
            longitude: longitude,
            descriptorArchive: descriptorArchive,
            barcodeDescription: barcodeDescription,
            timestamp: timestamp,
            isFavorite: isFavorite,
            tags: tags ?? [],
            address: address,
            isGenerated: isGenerated,
            lastModified: lastModified ?? .distantPast,
            correctionLevel: correctionLevel,
            isCompactStyle: isCompactStyle ?? false,
            compactionMode: compactionMode,
            columnCount: columnCount
        )
    }
}
