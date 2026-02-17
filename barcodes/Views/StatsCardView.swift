import SwiftUI

struct StatsCardView: View {
    let totalBarcodes: Int
    let uniqueValues: Int
    let favorites: Int
    let tagged: Int
    let withLocation: Int
    let generated: Int
    let typeBreakdown: [(type: BarcodeType, count: Int)]

    private var topTypes: [(type: BarcodeType, count: Int)] {
        Array(typeBreakdown.prefix(6))
    }

    private var maxTypeCount: Int {
        topTypes.first?.count ?? 1
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "barcode.viewfinder")
                    .font(.title2.weight(.semibold))
                Text("Barcode Stats")
                    .font(.title2.bold())
            }
            .padding(.bottom, 4)

            // Localized explicitly - String param in statCell() bypasses LocalizedStringKey lookup
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                statCell(
                    icon: "barcode",
                    label: String(localized: "Total Barcodes", comment: "Stats: total barcode count label"),
                    value: totalBarcodes
                )
                statCell(
                    icon: "number",
                    label: String(localized: "Unique", comment: "Stats card: unique barcode values label"),
                    value: uniqueValues
                )
                statCell(
                    icon: "star.fill",
                    label: String(localized: "Favorites", comment: "Stats: favorited barcodes label"),
                    value: favorites
                )
                statCell(
                    icon: "tag.fill",
                    label: String(localized: "Tagged", comment: "Stats: tagged barcodes label"),
                    value: tagged
                )
                statCell(
                    icon: "location.fill",
                    label: String(localized: "With Location", comment: "Stats: barcodes with GPS data label"),
                    value: withLocation
                )
                statCell(
                    icon: "plus.viewfinder",
                    label: String(localized: "Generated", comment: "Stats: user-created barcodes label"),
                    value: generated
                )
            }

            if !topTypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By Type")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(topTypes, id: \.type) { item in
                        HStack(spacing: 8) {
                            Text(item.type.localizedName)
                                .font(.caption)
                                .frame(width: 70, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.tint)
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxTypeCount))
                            }
                            .frame(height: 14)

                            Text("\(item.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }

            HStack {
                Text(Date.now, format: .dateTime.month().day().year())
                Text("·")
                Text("Barcode Stash")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 360)
        .background(Color(.systemBackground))
    }

    private func statCell(icon: String, label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.tint)
            Text("\(value)")
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 8))
    }
}
