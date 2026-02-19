import SwiftData
import SwiftUI
import UIKit

struct BarcodeRowView: View {
    let barcode: ScannedBarcode
    @Binding var shareBarcode: ScannedBarcode?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationLink(value: barcode) {
            rowContent
        }
        .accessibilityIdentifier("barcode-row-\(barcode.rawValue)")
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(String(
            localized: "Double-tap to view details. Swipe right to favorite.",
            comment: "History: barcode row hint"
        ))
        .swipeActions(edge: .leading) {
            Button {
                barcode.isFavorite.toggle()
                barcode.lastModified = .now
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: barcode.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                modelContext.delete(barcode)
            } label: {
                Image(systemName: "trash")
            }
        }
        .contextMenu {
            contextMenuContent
        }
    }

    private var accessibilityLabelText: String {
        if barcode.isFavorite {
            String(
                localized: "\(barcode.type.rawValue), \(barcode.rawValue), favorited",
                comment: "History: barcode row, favorited"
            )
        } else {
            String(
                localized: "\(barcode.type.rawValue), \(barcode.rawValue)",
                comment: "History: barcode row"
            )
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            BarcodePreviewView(barcode: barcode, size: CGSize(width: 50, height: 50))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if barcode.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    if barcode.isGenerated {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    Text(barcode.type.localizedName)
                        .font(.headline)
                }
                if let description = barcode.barcodeDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(barcode.rawValue)
                    .font(.subheadline.monospaced())
                    .lineLimit(1)
                if !barcode.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(barcode.tags.prefix(3), id: \.self) { tag in
                            TagChipView(tag: tag)
                        }
                        if barcode.tags.count > 3 {
                            Text("+\(barcode.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text(barcode.timestamp, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if barcode.latitude == nil {
                        Image(systemName: "location.slash")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            barcode.isFavorite.toggle()
            barcode.lastModified = .now
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label(
                barcode.isFavorite
                    ? String(localized: "Unfavorite", comment: "History: context menu unfavorite action")
                    : String(localized: "Favorite", comment: "History: context menu favorite action"),
                systemImage: barcode.isFavorite ? "star.slash" : "star.fill"
            )
        }

        Button {
            UIPasteboard.general.string = barcode.rawValue
        } label: {
            Label("Copy Value", systemImage: "doc.on.doc")
        }

        Button {
            shareBarcode = barcode
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            modelContext.delete(barcode)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
