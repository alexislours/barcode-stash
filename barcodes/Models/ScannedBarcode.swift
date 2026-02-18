import AVFoundation
import Foundation
import SwiftData
import Vision

enum BarcodeType: String, Codable, CaseIterable {
    // swiftlint:disable:next identifier_name
    case qr = "QR"
    case ean13 = "EAN-13"
    case ean8 = "EAN-8"
    case upce = "UPC-E"
    case code128 = "Code 128"
    case code39 = "Code 39"
    case code93 = "Code 93"
    case pdf417 = "PDF417"
    case aztec = "Aztec"
    case dataMatrix = "DataMatrix"
    case itf14 = "ITF-14"

    var metadataObjectType: AVMetadataObject.ObjectType {
        switch self {
        case .qr: .qr
        case .ean13: .ean13
        case .ean8: .ean8
        case .upce: .upce
        case .code128: .code128
        case .code39: .code39
        case .code93: .code93
        case .pdf417: .pdf417
        case .aztec: .aztec
        case .dataMatrix: .dataMatrix
        case .itf14: .itf14
        }
    }

    var localizedName: String {
        // Barcode format names are technical and don't need translation,
        // but routed through String(localized:) for consistency.
        String(localized: String.LocalizationValue(rawValue))
    }

    nonisolated init?(symbology: VNBarcodeSymbology) {
        let mapping: [VNBarcodeSymbology: BarcodeType] = [
            .qr: .qr,
            .ean13: .ean13,
            .ean8: .ean8,
            .upce: .upce,
            .code128: .code128,
            .code39: .code39,
            .code93: .code93,
            .pdf417: .pdf417,
            .aztec: .aztec,
            .dataMatrix: .dataMatrix,
            .itf14: .itf14,
        ]
        guard let barcodeType = mapping[symbology] else { return nil }
        self = barcodeType
    }

    init?(metadataType: AVMetadataObject.ObjectType) {
        let mapping: [AVMetadataObject.ObjectType: BarcodeType] = [
            .qr: .qr,
            .ean13: .ean13,
            .ean8: .ean8,
            .upce: .upce,
            .code128: .code128,
            .code39: .code39,
            .code93: .code93,
            .pdf417: .pdf417,
            .aztec: .aztec,
            .dataMatrix: .dataMatrix,
            .itf14: .itf14,
        ]
        guard let barcodeType = mapping[metadataType] else { return nil }
        self = barcodeType
    }
}

@Model
final class ScannedBarcode {
    var rawValue: String = ""
    var type: BarcodeType = BarcodeType.qr
    var latitude: Double?
    var longitude: Double?
    var descriptorArchive: Data?
    var barcodeDescription: String?
    var timestamp: Date = Date.now
    var isFavorite: Bool = false
    var tags: [String] = []
    var address: String?
    var isGenerated: Bool = false
    var lastModified: Date = Date.distantPast

    /// Advanced generator options (QR / Aztec / PDF417)
    var correctionLevel: String?
    var isCompactStyle: Bool = false
    var compactionMode: String?
    var columnCount: Int?

    /// Cache-key suffix built from non-nil generator options.
    var generatorOptionsKey: String? {
        var parts: [String] = []
        if let correctionLevel { parts.append("ecc:\(correctionLevel)") }
        if isCompactStyle { parts.append("compact:true") }
        if let compactionMode { parts.append("compaction:\(compactionMode)") }
        if let columnCount { parts.append("cols:\(columnCount)") }
        return parts.isEmpty ? nil : parts.joined(separator: "|")
    }

    init(
        rawValue: String,
        type: BarcodeType,
        latitude: Double? = nil,
        longitude: Double? = nil,
        descriptorArchive: Data? = nil,
        barcodeDescription: String? = nil,
        timestamp: Date = .now,
        isFavorite: Bool = false,
        tags: [String] = [],
        address: String? = nil,
        isGenerated: Bool = false,
        lastModified: Date = Date.distantPast,
        correctionLevel: String? = nil,
        isCompactStyle: Bool = false,
        compactionMode: String? = nil,
        columnCount: Int? = nil
    ) {
        self.rawValue = rawValue
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.descriptorArchive = descriptorArchive
        self.barcodeDescription = barcodeDescription
        self.timestamp = timestamp
        self.isFavorite = isFavorite
        self.tags = tags
        self.address = address
        self.isGenerated = isGenerated
        self.lastModified = lastModified
        self.correctionLevel = correctionLevel
        self.isCompactStyle = isCompactStyle
        self.compactionMode = compactionMode
        self.columnCount = columnCount
    }
}
