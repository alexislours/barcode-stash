import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCorrectionLevel: String, CaseIterable {
    case low = "L", medium = "M", quartile = "Q", high = "H"

    var label: String {
        switch self {
        case .low: "L (7%)"
        case .medium: "M (15%)"
        case .quartile: "Q (25%)"
        case .high: "H (30%)"
        }
    }
}

enum PDF417CompactionMode: String, CaseIterable {
    case automatic, numeric, text, byte

    var label: String {
        switch self {
        case .automatic:
            String(localized: "Automatic", comment: "PDF417 compaction mode: automatic")
        case .numeric:
            String(localized: "Numeric", comment: "PDF417 compaction mode: numeric")
        case .text:
            String(localized: "Text", comment: "PDF417 compaction mode: text")
        case .byte:
            String(localized: "Byte", comment: "PDF417 compaction mode: byte")
        }
    }

    var filterValue: Float {
        switch self {
        case .automatic: 0
        case .numeric: 1
        case .text: 2
        case .byte: 3
        }
    }
}

enum BarcodeGenerator {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Public API

    static func generateImage(for barcode: ScannedBarcode, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let outputImage: CIImage? = if let descriptorImage = generateFromDescriptor(barcode: barcode) {
            descriptorImage
        } else if let customImage = generateCustomBarcode(barcode: barcode) {
            customImage
        } else {
            generateFromCIFilter(barcode: barcode)
        }

        guard let image = outputImage else { return nil }

        // Render at native resolution first to avoid CIContext interpolation
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return nil }

        // Scale using nearest-neighbor to keep barcode edges crisp
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = Int(image.extent.width * scale)
        let scaledHeight = Int(image.extent.height * scale)
        guard scaledWidth > 0, scaledHeight > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .none
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        guard let scaledCGImage = ctx.makeImage() else { return nil }
        return UIImage(cgImage: scaledCGImage)
    }

    // MARK: - Descriptor-Based (pixel-identical for QR, Aztec, PDF417, DataMatrix)

    private static func generateFromDescriptor(barcode: ScannedBarcode) -> CIImage? {
        guard let archive = barcode.descriptorArchive,
              let descriptor = try? NSKeyedUnarchiver.unarchivedObject(
                  ofClasses: [
                      CIBarcodeDescriptor.self,
                      CIQRCodeDescriptor.self,
                      CIAztecCodeDescriptor.self,
                      CIPDF417CodeDescriptor.self,
                      CIDataMatrixCodeDescriptor.self,
                  ], from: archive
              ) as? CIBarcodeDescriptor
        else { return nil }

        // Data Matrix: CIFilter.barcodeGenerator() doesn't support it,
        // so render directly from the descriptor's payload and dimensions.
        if let dataMatrix = descriptor as? CIDataMatrixCodeDescriptor {
            return DataMatrixEncoder.generateImage(
                fromPayload: dataMatrix.errorCorrectedPayload,
                rowCount: dataMatrix.rowCount,
                columnCount: dataMatrix.columnCount,
                eccVersion: dataMatrix.eccVersion
            )
        }

        let filter = CIFilter.barcodeGenerator()
        filter.barcodeDescriptor = descriptor
        return filter.outputImage
    }

    // MARK: - CIFilter-Based (QR fallback, Code 128, PDF417, Aztec)

    private static func generateFromCIFilter(barcode: ScannedBarcode) -> CIImage? {
        let filter: CIFilter? = switch barcode.type {
        case .qr: makeQRFilter(for: barcode)
        case .pdf417: makePDF417Filter(for: barcode)
        case .aztec: makeAztecFilter(for: barcode)
        case .dataMatrix: nil
        default: makeCode128Filter(for: barcode)
        }
        return filter?.outputImage
    }

    private static func makeQRFilter(for barcode: ScannedBarcode) -> CIFilter {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(barcode.rawValue.utf8)
        filter.correctionLevel = barcode.correctionLevel ?? "M"
        return filter
    }

    private static func makeCode128Filter(for barcode: ScannedBarcode) -> CIFilter {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(barcode.rawValue.utf8)
        return filter
    }

    private static func makePDF417Filter(for barcode: ScannedBarcode) -> CIFilter {
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = Data(barcode.rawValue.utf8)
        if let level = barcode.correctionLevel, let intLevel = Int(level) {
            filter.correctionLevel = Float(intLevel)
        }
        if let mode = barcode.compactionMode,
           let compaction = PDF417CompactionMode(rawValue: mode) {
            filter.compactionMode = compaction.filterValue
        }
        filter.compactStyle = barcode.isCompactStyle ? 1 : 0
        if let cols = barcode.columnCount, cols > 0 {
            filter.dataColumns = Float(cols)
        }
        return filter
    }

    private static func makeAztecFilter(for barcode: ScannedBarcode) -> CIFilter {
        let filter = CIFilter.aztecCodeGenerator()
        filter.message = Data(barcode.rawValue.utf8)
        if let level = barcode.correctionLevel, let pct = Float(level) {
            filter.correctionLevel = pct
        }
        filter.compactStyle = barcode.isCompactStyle ? 1 : 0
        return filter
    }

    // MARK: - Custom Barcode Generation

    private static func generateCustomBarcode(barcode: ScannedBarcode) -> CIImage? {
        let modules: [Bool]?
        switch barcode.type {
        case .ean13: modules = encodeEAN13(barcode.rawValue)
        case .ean8: modules = encodeEAN8(barcode.rawValue)
        case .upce: modules = encodeUPCE(barcode.rawValue)
        case .code39: modules = encodeCode39(barcode.rawValue)
        case .code93: modules = encodeCode93(barcode.rawValue)
        case .itf14: modules = encodeITF14(barcode.rawValue)
        case .dataMatrix:
            return DataMatrixEncoder.generateImage(for: barcode.rawValue)
        default: modules = nil
        }
        guard let modules else { return nil }
        return renderModules(modules)
    }

    // MARK: - Module Renderer

    static func renderModules(_ modules: [Bool], scale: Int = 4) -> CIImage? {
        let quietZone = 10 * scale
        let moduleWidth = scale
        let height = 60 * scale
        let totalWidth = modules.count * moduleWidth + quietZone * 2
        var pixels = [UInt8](repeating: 255, count: totalWidth * height)

        for (idx, isBar) in modules.enumerated() where isBar {
            let xStart = quietZone + idx * moduleWidth
            for xOffset in 0 ..< moduleWidth {
                for yPos in 0 ..< height {
                    pixels[yPos * totalWidth + xStart + xOffset] = 0
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                  width: totalWidth, height: height,
                  bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: totalWidth,
                  space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: 0),
                  provider: provider, decode: nil, shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else { return nil }

        return CIImage(cgImage: cgImage)
    }
}
