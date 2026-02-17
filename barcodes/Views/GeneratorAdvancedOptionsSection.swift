import SwiftUI

struct GeneratorAdvancedOptionsSection: View {
    let selectedType: BarcodeType
    @Binding var qrCorrectionLevel: QRCorrectionLevel
    @Binding var aztecCorrectionLevel: Double
    @Binding var aztecCompactStyle: Bool
    @Binding var pdf417CorrectionLevel: Int
    @Binding var pdf417CompactionMode: PDF417CompactionMode
    @Binding var pdf417CompactStyle: Bool
    @Binding var pdf417ColumnCount: Int

    var body: some View {
        switch selectedType {
        case .qr:
            qrSection
        case .aztec:
            aztecSection
        case .pdf417:
            pdf417Section
        default:
            EmptyView()
        }
    }

    private var qrSection: some View {
        Section {
            DisclosureGroup(
                String(localized: "Advanced Options",
                       comment: "Generator: advanced options disclosure group title")
            ) {
                Picker(
                    String(localized: "Error Correction",
                           comment: "Generator: QR error correction picker label"),
                    selection: $qrCorrectionLevel
                ) {
                    ForEach(QRCorrectionLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
            }
        }
    }

    private var aztecSection: some View {
        Section {
            DisclosureGroup(
                String(localized: "Advanced Options",
                       comment: "Generator: advanced options disclosure group title")
            ) {
                VStack(alignment: .leading) {
                    Text(
                        String(
                            localized: "Error Correction: \(Int(aztecCorrectionLevel))%",
                            comment: "Generator: Aztec error correction slider label"
                        )
                    )
                    .font(.subheadline)
                    Slider(value: $aztecCorrectionLevel, in: 5 ... 95, step: 1)
                }
                Toggle(
                    String(localized: "Compact Style",
                           comment: "Generator: compact style toggle label"),
                    isOn: $aztecCompactStyle
                )
            }
        }
    }

    private var pdf417Section: some View {
        Section {
            DisclosureGroup(
                String(localized: "Advanced Options",
                       comment: "Generator: advanced options disclosure group title")
            ) {
                Picker(
                    String(localized: "Error Correction",
                           comment: "Generator: PDF417 error correction picker label"),
                    selection: $pdf417CorrectionLevel
                ) {
                    ForEach(0 ... 8, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
                Picker(
                    String(localized: "Compaction Mode",
                           comment: "Generator: PDF417 compaction mode picker label"),
                    selection: $pdf417CompactionMode
                ) {
                    ForEach(PDF417CompactionMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Toggle(
                    String(localized: "Compact Style",
                           comment: "Generator: compact style toggle label"),
                    isOn: $pdf417CompactStyle
                )
                Stepper(value: $pdf417ColumnCount, in: 0 ... 30) {
                    HStack {
                        Text(
                            String(localized: "Columns",
                                   comment: "Generator: PDF417 column count stepper label")
                        )
                        Spacer()
                        Text(
                            pdf417ColumnCount == 0
                                ? String(localized: "Auto",
                                         comment: "Generator: automatic column count value")
                                : "\(pdf417ColumnCount)"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
