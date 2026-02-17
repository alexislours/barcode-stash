import CoreLocation
import SwiftData
import SwiftUI

struct ScannerOverlayCard: View {
    let value: String
    let type: BarcodeType
    let descriptorArchive: Data?
    let duplicateBarcode: ScannedBarcode?
    let location: CLLocation?
    let onSave: (ScannedBarcode) -> Void
    let onViewExisting: (ScannedBarcode) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            let preview = ScannedBarcode(
                rawValue: value,
                type: type,
                descriptorArchive: descriptorArchive
            )

            BarcodePreviewView(barcode: preview, size: CGSize(width: 200, height: 120))
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            VStack(spacing: 4) {
                Text(type.localizedName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)

                Text(value)
                    .font(.body.monospaced())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if let existing = duplicateBarcode {
                duplicateWarningButtons(existing: existing)
            } else {
                saveButtons
            }
        }
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .drawingGroup()
        .padding()
    }

    private func duplicateWarningButtons(existing: ScannedBarcode) -> some View {
        VStack(spacing: 8) {
            Label(
                "Already saved \(existing.timestamp.formatted(date: .abbreviated, time: .shortened))",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.top, 8)

            Button {
                onViewExisting(existing)
            } label: {
                Text("View Existing")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 8) {
                Button {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onSave(ScannedBarcode(
                        rawValue: value,
                        type: type,
                        latitude: location?.coordinate.latitude,
                        longitude: location?.coordinate.longitude,
                        descriptorArchive: descriptorArchive
                    ))
                } label: {
                    Text("Save Anyway")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var saveButtons: some View {
        HStack(spacing: 8) {
            Button {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onSave(ScannedBarcode(
                    rawValue: value,
                    type: type,
                    latitude: location?.coordinate.latitude,
                    longitude: location?.coordinate.longitude,
                    descriptorArchive: descriptorArchive
                ))
            } label: {
                Text("Save")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("save-barcode-button")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}
