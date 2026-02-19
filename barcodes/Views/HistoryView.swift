import PhotosUI
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \ScannedBarcode.timestamp, order: .reverse) var barcodes: [ScannedBarcode]
    @Binding var selectedBarcode: ScannedBarcode?
    @Binding var isSelectMode: Bool
    @Binding var pendingSharedImageScan: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var filterFavorites = false
    @State private var sourceFilter: HistorySourceFilter = .all
    @State private var selectedTag: String?

    // Batch operations
    @State var editMode: EditMode = .inactive
    @State var selectedBarcodeIDs: Set<PersistentIdentifier> = []
    @State var showBatchDeleteConfirmation = false
    @State var showBatchTagSheet = false
    @State var batchTagText = ""
    @State var batchExportFileURL: URL?
    @State var exportError: String?
    @State private var shareBarcode: ScannedBarcode?

    // Image scanning
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var imageScanResults: [DetectedBarcode] = []
    @State private var showImageScanResults = false
    @State private var isImageScanning = false
    @State private var showNoBarcodeAlert = false

    var isEditing: Bool {
        editMode == .active
    }

    private var allTags: [String] {
        Array(Set(barcodes.flatMap(\.tags))).sorted()
    }

    private var activeFilterCount: Int {
        (filterFavorites ? 1 : 0) + (sourceFilter != .all ? 1 : 0) + (selectedTag != nil ? 1 : 0)
    }

    private var isFiltering: Bool {
        filterFavorites || sourceFilter != .all || selectedTag != nil
    }

    var filteredBarcodes: [ScannedBarcode] {
        var result = barcodes

        if !searchText.isEmpty {
            result = result.filter { barcode in
                barcode.rawValue.localizedCaseInsensitiveContains(searchText)
                    || barcode.type.rawValue.localizedCaseInsensitiveContains(searchText)
                    || (barcode.barcodeDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || barcode.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        switch sourceFilter {
        case .all: break
        case .scanned: result = result.filter { !$0.isGenerated }
        case .generated: result = result.filter(\.isGenerated)
        }

        if filterFavorites {
            result = result.filter(\.isFavorite)
        }

        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        return result
    }

    private var groupedByDay: [(date: Date, barcodes: [ScannedBarcode])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredBarcodes) { barcode in
            calendar.startOfDay(for: barcode.timestamp)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, barcodes: $0.value) }
    }

    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "Today", comment: "History section header: today's date")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday", comment: "History section header: yesterday's date")
        } else {
            return date.formatted(.dateTime.month(.wide).day().year())
        }
    }

    var body: some View {
        NavigationStack {
            barcodeList
                .alert("Delete Selected", isPresented: $showBatchDeleteConfirmation) {
                    Button("Delete \(selectedBarcodeIDs.count)", role: .destructive) {
                        batchDelete()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Delete \(selectedBarcodeIDs.count) barcodes? This cannot be undone.")
                }
                .sheet(isPresented: $showBatchTagSheet) {
                    batchTagSheet
                }
                .sheet(item: $batchExportFileURL) { url in
                    ShareSheetView(items: [url])
                }
                .sheet(item: $shareBarcode) { barcode in
                    ShareBarcodeSheet(barcode: barcode)
                }
                .alert("Export Failed", isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )) {
                    Button("OK") { exportError = nil }
                } message: {
                    Text(exportError ?? "")
                }
                .onChange(of: searchText) {
                    selectedBarcodeIDs.removeAll()
                }
                .onChange(of: filterFavorites) {
                    selectedBarcodeIDs.removeAll()
                }
                .onChange(of: sourceFilter) {
                    selectedBarcodeIDs.removeAll()
                }
                .onChange(of: selectedTag) {
                    selectedBarcodeIDs.removeAll()
                }
                .onChange(of: isEditing) {
                    isSelectMode = isEditing
                }
                .onChange(of: selectedPhotoItems) {
                    guard !selectedPhotoItems.isEmpty else { return }
                    let items = selectedPhotoItems
                    selectedPhotoItems = []
                    Task {
                        await processSelectedPhotos(items)
                    }
                }
                .sheet(isPresented: $showImageScanResults) {
                    ImageScanResultsView(detectedBarcodes: imageScanResults)
                }
                .alert(
                    String(
                        localized: "No Barcodes Found",
                        comment: "Image scan: no results alert title"
                    ),
                    isPresented: $showNoBarcodeAlert
                ) {
                    Button("OK") {}
                } message: {
                    Text(
                        "No supported barcodes were detected in this image.",
                        comment: "Image scan: no results alert message"
                    )
                }
                .onChange(of: pendingSharedImageScan) { handlePendingSharedImageScan() }
                .onAppear { handlePendingSharedImageScan() }
        }
    }

    private var listSelection: Binding<Set<PersistentIdentifier>>? {
        isEditing ? $selectedBarcodeIDs : nil
    }

    private var barcodeList: some View {
        List(selection: listSelection) {
            ForEach(groupedByDay, id: \.date) { group in
                Section(sectionHeader(for: group.date)) {
                    ForEach(group.barcodes) { barcode in
                        BarcodeRowView(
                            barcode: barcode,
                            shareBarcode: $shareBarcode
                        )
                        .tag(barcode.persistentModelID)
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search barcodes"
        )
        .navigationTitle("History")
        .toolbar(content: historyToolbar)
        .safeAreaInset(edge: .bottom) {
            batchToolbar
                .padding(.vertical, 10)
                .opacity(isEditing ? 1 : 0)
                .allowsHitTesting(isEditing)
        }
        .navigationDestination(for: ScannedBarcode.self) { barcode in
            BarcodeDetailView(barcode: barcode)
        }
        .navigationDestination(item: $selectedBarcode) { barcode in
            BarcodeDetailView(barcode: barcode)
        }
        .overlay {
            emptyStateOverlay
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func historyToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            selectButton
        }
        if isEditing {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    editingSelectAllButton
                    editingTagButton
                }
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                trailingToolbar
            }
        }
    }

    // MARK: - Trailing Toolbar

    private var trailingToolbar: some View {
        let scanning = isImageScanning
        return HStack(spacing: 12) {
            if horizontalSizeClass == .regular {
                Button { isSearchPresented.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityIdentifier("search-button")
            }
            PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                if scanning {
                    ProgressView()
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                }
            }
            .disabled(isImageScanning)
            .accessibilityLabel(
                String(
                    localized: "Scan from image",
                    comment: "History: scan barcode from photo library"
                )
            )
            .accessibilityHint(
                String(
                    localized: "Opens photo picker to scan barcodes from an image",
                    comment: "History: scan from image button hint"
                )
            )

            NavigationLink {
                StatsView()
            } label: {
                Image(systemName: "chart.bar")
            }
            .disabled(barcodes.isEmpty)
            .accessibilityLabel(String(
                localized: "Statistics",
                comment: "History: stats navigation link"
            ))
            .accessibilityIdentifier("statistics-button")

            HistoryFilterMenu(
                sourceFilter: $sourceFilter,
                filterFavorites: $filterFavorites,
                selectedTag: $selectedTag,
                allTags: allTags,
                isFiltering: isFiltering,
                activeFilterCount: activeFilterCount
            )
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if barcodes.isEmpty {
            ContentUnavailableView(
                "No Barcodes",
                systemImage: "barcode.viewfinder",
                description: Text("Scanned and created barcodes will appear here.")
            )
        } else if filteredBarcodes.isEmpty {
            if isFiltering {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("No barcodes match the active filters.")
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    // MARK: - Image Scanning

    private func handlePendingSharedImageScan() {
        guard pendingSharedImageScan else { return }
        pendingSharedImageScan = false
        Task { await processSharedImages() }
    }

    private func presentScanResults(_ results: [DetectedBarcode]) {
        if results.isEmpty {
            showNoBarcodeAlert = true
        } else {
            imageScanResults = results
            showImageScanResults = true
        }
    }

    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isImageScanning = true
        defer { isImageScanning = false }

        var allDetected: [DetectedBarcode] = []
        var seen = Set<String>()

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            let detected = await (try? Task.detached {
                try ImageBarcodeScanner.detectBarcodes(from: data)
            }.value) ?? []

            for barcode in detected {
                let key = "\(barcode.type.rawValue)|\(barcode.rawValue)"
                if seen.insert(key).inserted {
                    allDetected.append(barcode)
                }
            }
        }

        presentScanResults(allDetected)
    }

    // MARK: - Shared Image Scanning (Share Extension)

    private func processSharedImages() async {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.alexislours.barcodes-app"
        ) else { return }

        let sharedDir = containerURL.appendingPathComponent("SharedImages", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sharedDir, includingPropertiesForKeys: nil
        ), !files.isEmpty else { return }

        isImageScanning = true
        defer { isImageScanning = false }

        var allDetected: [DetectedBarcode] = []
        var seen = Set<String>()

        for fileURL in files {
            guard let data = try? Data(contentsOf: fileURL) else {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }

            let detected = await (try? Task.detached {
                try ImageBarcodeScanner.detectBarcodes(from: data)
            }.value) ?? []

            for barcode in detected {
                let key = "\(barcode.type.rawValue)|\(barcode.rawValue)"
                if seen.insert(key).inserted {
                    allDetected.append(barcode)
                }
            }

            try? FileManager.default.removeItem(at: fileURL)
        }

        presentScanResults(allDetected)
    }
}
