import MapKit
import SwiftUI

struct ShareableBarcodeView: View {
    let barcode: ScannedBarcode
    let barcodeImage: UIImage?
    var mapSnapshot: UIImage?
    var showDescription: Bool = true
    var showRawValue: Bool = true
    var showType: Bool = true
    var showDate: Bool = true
    var showMap: Bool = true
    var showAddress: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            if let barcodeImage {
                Image(uiImage: barcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 6) {
                if showType {
                    Text(barcode.type.localizedName)
                        .font(.headline)
                }

                if showRawValue {
                    Text(barcode.rawValue)
                        .font(.subheadline.monospaced())
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                }

                if showDate {
                    Text(barcode.timestamp, format: .dateTime.month().day().year().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if showDescription, let desc = barcode.barcodeDescription, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if showAddress, let address = barcode.address {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                    Text(address)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            if showMap, let mapSnapshot {
                Image(uiImage: mapSnapshot)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, -20)
            }
        }
        .padding(20)
        .clipped()
        .frame(width: 360)
        .background(Color(.systemBackground))
    }
}
