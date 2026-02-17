import CoreLocation
import SwiftData
import SwiftUI

struct ScannerResultOverlay: View {
    @Environment(\.modelContext) private var modelContext

    let showScanResult: Bool
    let isBulkMode: Bool
    let scannedValue: String?
    let scannedType: BarcodeType?
    let scannedDescriptorArchive: Data?
    let duplicateBarcode: ScannedBarcode?
    let barcodeBounds: CGRect?
    let location: CLLocation?
    let onSave: ((ScannedBarcode) -> Void)?
    let onDismiss: () -> Void
    let onResetScan: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            if showScanResult {
                Color.black.opacity(0.4)
                    .transition(.opacity)
            }

            if !isBulkMode, showScanResult, let value = scannedValue, let type = scannedType {
                let anchor = barcodeBounds.map { CGPoint(x: $0.midX, y: $0.midY) } ?? center

                ScannerOverlayCard(
                    value: value,
                    type: type,
                    descriptorArchive: scannedDescriptorArchive,
                    duplicateBarcode: duplicateBarcode,
                    location: location,
                    onSave: { barcode in
                        modelContext.insert(barcode)
                        if let lat = barcode.latitude, let lon = barcode.longitude {
                            Task {
                                barcode.address = await ReverseGeocoder.reverseGeocode(
                                    latitude: lat,
                                    longitude: lon
                                )
                            }
                        }
                        onSave?(barcode)
                        onDismiss()
                    },
                    onViewExisting: { existing in
                        onSave?(existing)
                        onDismiss()
                    },
                    onCancel: onResetScan
                )
                .position(center)
                .transition(
                    .asymmetric(
                        insertion: .offset(
                            x: anchor.x - center.x,
                            y: anchor.y - center.y
                        )
                        .combined(with: .scale(scale: 0.15))
                        .combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    )
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(showScanResult)
    }
}
