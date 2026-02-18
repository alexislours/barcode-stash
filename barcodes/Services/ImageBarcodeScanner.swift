import ImageIO
import Vision

struct DetectedBarcode: Sendable, Identifiable {
    nonisolated let id = UUID()
    let rawValue: String
    let type: BarcodeType
    let descriptorArchive: Data?
    let latitude: Double?
    let longitude: Double?
}

enum ImageBarcodeScanner {
    /// Vision symbologies matching supported `BarcodeType` cases.
    private nonisolated static let supportedSymbologies: [VNBarcodeSymbology] = [
        .qr, .ean13, .ean8, .upce,
        .code128, .code39, .code93,
        .pdf417, .aztec, .dataMatrix, .itf14,
    ]

    /// Detects barcodes in the given image, filtering to supported types and deduplicating.
    nonisolated static func detectBarcodes(in cgImage: CGImage) throws -> [DetectedBarcode] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = supportedSymbologies

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else { return [] }

        var seen = Set<String>()
        return observations.compactMap { observation in
            guard let payload = observation.payloadStringValue,
                  let type = BarcodeType(symbology: observation.symbology)
            else { return nil }

            let key = "\(type.rawValue)|\(payload)"
            guard seen.insert(key).inserted else { return nil }

            var archive: Data?
            if let descriptor = observation.barcodeDescriptor {
                archive = try? NSKeyedArchiver.archivedData(
                    withRootObject: descriptor,
                    requiringSecureCoding: true
                )
            }

            return DetectedBarcode(
                rawValue: payload, type: type, descriptorArchive: archive,
                latitude: nil, longitude: nil
            )
        }
    }

    /// Creates a downsampled CGImage suitable for Vision without decoding the full bitmap.
    nonisolated static func downsampledCGImage(from data: Data, maxPixelSize: Int = 4096) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Downsamples image data, extracts GPS coordinates, and detects barcodes in one pass.
    nonisolated static func detectBarcodes(from data: Data, maxPixelSize: Int = 4096) throws -> [DetectedBarcode] {
        guard let cgImage = downsampledCGImage(from: data, maxPixelSize: maxPixelSize) else { return [] }
        let coordinates = extractGPSCoordinates(from: data)
        let barcodes = try detectBarcodes(in: cgImage)
        return barcodes.map { barcode in
            DetectedBarcode(
                rawValue: barcode.rawValue, type: barcode.type,
                descriptorArchive: barcode.descriptorArchive,
                latitude: coordinates?.latitude, longitude: coordinates?.longitude
            )
        }
    }

    /// Extracts GPS coordinates from image EXIF metadata.
    nonisolated static func extractGPSCoordinates(from data: Data) -> (latitude: Double, longitude: Double)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
        else { return nil }

        let lat = latRef == "S" ? -latitude : latitude
        let lon = lonRef == "W" ? -longitude : longitude
        return (lat, lon)
    }
}
