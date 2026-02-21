import SwiftUI

enum HistorySourceFilter: String, CaseIterable {
    case all = "All"
    case scanned = "Scanned"
    case generated = "Generated"

    var localizedName: String {
        switch self {
        case .all: String(localized: "All", comment: "Source filter: show all barcodes")
        case .scanned: String(localized: "Scanned", comment: "Source filter: show scanned barcodes")
        case .generated: String(localized: "Generated", comment: "Source filter: show generated barcodes")
        }
    }
}

struct HistoryFilterMenu: View {
    @Binding var sourceFilter: HistorySourceFilter
    @Binding var filterFavorites: Bool
    @Binding var selectedTag: String?
    let allTags: [String]
    let isFiltering: Bool
    let activeFilterCount: Int

    var body: some View {
        Menu {
            Section("Source") {
                ForEach(HistorySourceFilter.allCases, id: \.self) { filter in
                    Button {
                        withAccessibleAnimation {
                            sourceFilter = sourceFilter == filter && filter != .all
                                ? .all : filter
                        }
                    } label: {
                        if sourceFilter == filter {
                            Label(filter.localizedName, systemImage: "checkmark")
                        } else {
                            Text(filter.localizedName)
                        }
                    }
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { filterFavorites },
                    set: { newValue in
                        withAccessibleAnimation {
                            filterFavorites = newValue
                        }
                    }
                )) {
                    Label("Favorites", systemImage: "star.fill")
                }
            }

            if !allTags.isEmpty {
                Section("Tags") {
                    ForEach(allTags, id: \.self) { tag in
                        Button {
                            withAccessibleAnimation {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        } label: {
                            if selectedTag == tag {
                                Label(tag, systemImage: "checkmark")
                            } else {
                                Text(tag)
                            }
                        }
                    }
                }
            }

            if isFiltering {
                Section {
                    Button("Clear Filters", role: .destructive) {
                        withAccessibleAnimation {
                            filterFavorites = false
                            sourceFilter = .all
                            selectedTag = nil
                        }
                    }
                }
            }
        } label: {
            filterMenuLabel
        }
        .accessibilityLabel(filterAccessibilityLabel)
    }

    private var filterAccessibilityLabel: String {
        if activeFilterCount > 0 {
            String(
                localized: "Filter, \(activeFilterCount) active",
                comment: "History: filter menu with active filter count"
            )
        } else {
            String(localized: "Filter", comment: "History: filter menu")
        }
    }

    private var filterMenuLabel: some View {
        Image(systemName: isFiltering
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle")
            .symbolRenderingMode(.hierarchical)
            .overlay(alignment: .topTrailing) {
                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.accentColor, in: Circle())
                        .offset(x: 6, y: -6)
                        .accessibilityHidden(true)
                }
            }
            .padding(.trailing, 6)
            .padding(.top, 2)
    }
}
