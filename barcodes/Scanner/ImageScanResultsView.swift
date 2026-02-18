import SwiftData
import SwiftUI

struct ImageScanResultsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let detectedBarcodes: [DetectedBarcode]

    @State private var selectedIDs: Set<UUID>
    @State private var existingKeys: Set<String> = []

    init(detectedBarcodes: [DetectedBarcode]) {
        self.detectedBarcodes = detectedBarcodes
        _selectedIDs = State(initialValue: Set(detectedBarcodes.map(\.id)))
    }

    private var selectedCount: Int {
        selectedIDs.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(detectedBarcodes) { barcode in
                        barcodeRow(barcode)
                    }
                } header: {
                    Text(
                        detectedBarcodes.count == 1
                            ? String(
                                localized: "1 barcode found",
                                comment: "Image scan: section header, one barcode"
                            )
                            : String(
                                localized: "\(detectedBarcodes.count) barcodes found",
                                comment: "Image scan: section header, multiple barcodes"
                            )
                    )
                }
            }
            .navigationTitle(
                String(localized: "Scan from Image", comment: "Image scan: navigation title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Image scan: cancel button")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        String(
                            localized: "Save (\(selectedCount))",
                            comment: "Image scan: save button with count"
                        )
                    ) {
                        saveSelected()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .task {
                loadExistingKeys()
            }
        }
    }

    // MARK: - Barcode Row

    private func barcodeRow(_ barcode: DetectedBarcode) -> some View {
        let duplicate = isDuplicate(barcode)
        let selected = selectedIDs.contains(barcode.id)

        return Button {
            if selected {
                selectedIDs.remove(barcode.id)
            } else {
                selectedIDs.insert(barcode.id)
            }
        } label: {
            HStack(spacing: 12) {
                BarcodePreviewView(
                    barcode: ScannedBarcode(
                        rawValue: barcode.rawValue,
                        type: barcode.type,
                        descriptorArchive: barcode.descriptorArchive
                    ),
                    size: CGSize(width: 50, height: 50)
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(barcode.type.localizedName)
                            .font(.headline)
                        if duplicate {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(barcode.rawValue)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let payload = BarcodePayloadParser.parse(
                        rawValue: barcode.rawValue,
                        type: barcode.type
                    ) {
                        Label(payload.actionLabel, systemImage: payload.systemImage)
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }

                    if duplicate {
                        Text(
                            String(
                                localized: "Already saved",
                                comment: "Image scan: duplicate barcode indicator"
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .blue : .secondary)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                localized: "\(barcode.type.rawValue), \(barcode.rawValue)",
                comment: "Image scan: barcode row"
            )
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Actions

    private func saveSelected() {
        let toSave = detectedBarcodes.filter { selectedIDs.contains($0.id) }
        for detected in toSave {
            let barcode = ScannedBarcode(
                rawValue: detected.rawValue,
                type: detected.type,
                latitude: detected.latitude,
                longitude: detected.longitude,
                descriptorArchive: detected.descriptorArchive
            )
            modelContext.insert(barcode)
            if let lat = detected.latitude, let lon = detected.longitude {
                Task {
                    barcode.address = await ReverseGeocoder.reverseGeocode(
                        latitude: lat,
                        longitude: lon
                    )
                }
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func loadExistingKeys() {
        let descriptor = FetchDescriptor<ScannedBarcode>()
        guard let existing = try? modelContext.fetch(descriptor) else { return }
        existingKeys = Set(existing.map { "\($0.type.rawValue)|\($0.rawValue)" })
    }

    private func isDuplicate(_ barcode: DetectedBarcode) -> Bool {
        existingKeys.contains("\(barcode.type.rawValue)|\(barcode.rawValue)")
    }
}
