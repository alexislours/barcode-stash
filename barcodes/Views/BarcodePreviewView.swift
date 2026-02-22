import SwiftUI

struct BarcodePreviewView: View {
    let barcode: ScannedBarcode
    var size: CGSize = .init(width: 200, height: 200)

    @State private var image: UIImage?

    private var cacheKey: NSString {
        BarcodeImageCache.cacheKey(
            rawValue: barcode.rawValue,
            type: barcode.type.rawValue,
            descriptorArchive: barcode.descriptorArchive,
            width: Int(size.width),
            height: Int(size.height),
            generatorOptions: barcode.generatorOptionsKey
        )
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size.width, maxHeight: size.height)
            } else {
                Image(systemName: "barcode.viewfinder")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(width: size.width, height: size.height)
            }
        }
        .onAppear {
            // Synchronous memory cache check to avoid placeholder flash
            if let cached = BarcodeImageCache.shared.image(for: cacheKey) {
                image = cached
            }
        }
        .task(id: cacheKey) {
            if image != nil { return }

            let key = cacheKey

            if let diskHit = await BarcodeImageCache.shared.cachedImage(for: key) {
                image = diskHit
                return
            }

            // Capture values from @Model on MainActor before crossing isolation boundary
            let rawValue = barcode.rawValue
            let type = barcode.type
            let descriptorArchive = barcode.descriptorArchive
            let correctionLevel = barcode.correctionLevel
            let isCompactStyle = barcode.isCompactStyle
            let compactionMode = barcode.compactionMode
            let columnCount = barcode.columnCount
            let targetSize = size

            let generated = await Task.detached {
                BarcodeGenerator.generateImage(
                    rawValue: rawValue,
                    type: type,
                    descriptorArchive: descriptorArchive,
                    correctionLevel: correctionLevel,
                    isCompactStyle: isCompactStyle,
                    compactionMode: compactionMode,
                    columnCount: columnCount,
                    size: targetSize
                )
            }.value

            if let generated {
                await BarcodeImageCache.shared.storeImage(generated, for: key)
                image = generated
            }
        }
    }
}
