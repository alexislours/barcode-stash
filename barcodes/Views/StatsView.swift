import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \ScannedBarcode.timestamp, order: .reverse) private var barcodes: [ScannedBarcode]
    @State private var shareImage: UIImage?

    private var uniqueValueCount: Int {
        Set(barcodes.map(\.rawValue)).count
    }

    private var typeBreakdown: [(type: BarcodeType, count: Int)] {
        Dictionary(grouping: barcodes, by: \.type)
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var favoriteCount: Int {
        barcodes.filter(\.isFavorite).count
    }

    private var taggedCount: Int {
        barcodes.filter { !$0.tags.isEmpty }.count
    }

    private var locationCount: Int {
        barcodes.filter { $0.latitude != nil }.count
    }

    private var generatedCount: Int {
        barcodes.filter(\.isGenerated).count
    }

    var body: some View {
        List {
            Section("Overview") {
                statRow(
                    icon: "barcode",
                    label: String(localized: "Total Barcodes", comment: "Stats: total barcode count label"),
                    value: "\(barcodes.count)"
                )
                statRow(
                    icon: "number",
                    label: String(localized: "Unique Values", comment: "Stats: unique barcode values label"),
                    value: "\(uniqueValueCount)"
                )
                statRow(
                    icon: "star.fill",
                    label: String(localized: "Favorites", comment: "Stats: favorited barcodes label"),
                    value: "\(favoriteCount)"
                )
                statRow(
                    icon: "tag.fill",
                    label: String(localized: "Tagged", comment: "Stats: tagged barcodes label"),
                    value: "\(taggedCount)"
                )
                statRow(
                    icon: "location.fill",
                    label: String(localized: "With Location", comment: "Stats: barcodes with GPS data label"),
                    value: "\(locationCount)"
                )
                statRow(
                    icon: "plus.viewfinder",
                    label: String(localized: "Generated", comment: "Stats: user-created barcodes label"),
                    value: "\(generatedCount)"
                )
            }

            if !typeBreakdown.isEmpty {
                Section("By Type") {
                    ForEach(typeBreakdown, id: \.type) { item in
                        HStack {
                            Text(item.type.localizedName)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("stats-list")
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareImage = renderStatsImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(barcodes.isEmpty)
            }
        }
        .sheet(isPresented: .init(
            get: { shareImage != nil },
            set: { if !$0 { shareImage = nil } }
        )) {
            if let shareImage {
                ShareSheetView(items: [shareImage])
            }
        }
    }

    private func renderStatsImage() -> UIImage? {
        let card = StatsCardView(
            totalBarcodes: barcodes.count,
            uniqueValues: uniqueValueCount,
            favorites: favoriteCount,
            tagged: taggedCount,
            withLocation: locationCount,
            generated: generatedCount,
            typeBreakdown: typeBreakdown
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
