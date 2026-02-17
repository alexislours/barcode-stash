import SwiftUI

struct ScannerControlBar: View {
    @Binding var isBulkMode: Bool
    @Binding var isTorchOn: Bool
    @Binding var allowedTypes: Set<BarcodeType>
    let bulkSavedCount: Int
    let hasOverlayCard: Bool
    let onDismiss: () -> Void

    private var isAllTypes: Bool {
        allowedTypes.count == BarcodeType.allCases.count
    }

    var body: some View {
        HStack {
            closeButton
            Spacer()
            bulkModeButton
            typeFilterMenu
            torchButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var closeButton: some View {
        Button {
            onDismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(String(localized: "Close scanner", comment: "Scanner: close button"))
    }

    private var bulkModeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isBulkMode, bulkSavedCount > 0 {
                // Scanned codes in bulk - exit back to list
                onDismiss()
                return
            }
            withAccessibleAnimation(.snappy) {
                isBulkMode.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "repeat")
                    .font(.body.weight(.semibold))
                if isBulkMode {
                    Text("Bulk")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(isBulkMode ? .white : .white.opacity(0.8))
            .padding(.horizontal, isBulkMode ? 10 : 0)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                isBulkMode
                    ? AnyShapeStyle(.green.opacity(0.7))
                    : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
        }
        .disabled(hasOverlayCard)
        .accessibilityLabel(bulkModeAccessibilityLabel)
        .accessibilityHint(
            String(
                localized: "Toggles continuous scanning mode",
                comment: "Scanner: bulk mode toggle hint"
            )
        )
    }

    private var typeFilterMenu: some View {
        Menu {
            Button {
                allowedTypes = Set(BarcodeType.allCases)
            } label: {
                if isAllTypes {
                    Label("All Types", systemImage: "checkmark")
                } else {
                    Text("All Types")
                }
            }

            Divider()

            ForEach(BarcodeType.allCases, id: \.self) { type in
                Button {
                    allowedTypes = [type]
                } label: {
                    if allowedTypes == [type] {
                        Label(type.localizedName, systemImage: "checkmark")
                    } else {
                        Text(type.localizedName)
                    }
                }
            }
        } label: {
            Image(systemName: isAllTypes
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .disabled(hasOverlayCard)
        .accessibilityLabel(typeFilterAccessibilityLabel)
    }

    private var torchButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isTorchOn.toggle()
        } label: {
            Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(isTorchOn ? .yellow : .white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(torchAccessibilityLabel)
        .accessibilityHint(
            String(
                localized: "Toggles the camera flashlight",
                comment: "Scanner: torch toggle hint"
            )
        )
    }

    private var bulkModeAccessibilityLabel: String {
        if isBulkMode {
            String(localized: "Bulk mode on", comment: "Scanner: bulk mode toggle on")
        } else {
            String(localized: "Bulk mode off", comment: "Scanner: bulk mode toggle off")
        }
    }

    private var typeFilterAccessibilityLabel: String {
        if isAllTypes {
            String(
                localized: "Barcode type filter",
                comment: "Scanner: type filter button, no filter active"
            )
        } else {
            String(
                localized: "Barcode type filter, filtered",
                comment: "Scanner: type filter button, filter active"
            )
        }
    }

    private var torchAccessibilityLabel: String {
        if isTorchOn {
            String(localized: "Torch on", comment: "Scanner: torch toggle on")
        } else {
            String(localized: "Torch off", comment: "Scanner: torch toggle off")
        }
    }
}
