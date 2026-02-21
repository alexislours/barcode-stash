import SwiftUI

struct ContentView: View {
    @Binding var pendingSharedImageScan: Bool
    var pendingQuickAction: QuickAction?
    var consumeQuickAction: () -> Void = {}
    @State private var showScanner = false
    @State private var pendingBarcode: ScannedBarcode?
    @State private var selectedBarcode: ScannedBarcode?
    @State private var selectedTab = 0
    @State private var isSelectMode = false
    @State private var filterFavorites = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Barcodes", systemImage: "barcode.viewfinder", value: 0) {
                HistoryView(
                    selectedBarcode: $selectedBarcode,
                    isSelectMode: $isSelectMode,
                    pendingSharedImageScan: $pendingSharedImageScan,
                    filterFavorites: $filterFavorites
                )
                .overlay(alignment: .bottomTrailing) {
                    if !isSelectMode {
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.tint, in: Circle())
                                .shadow(radius: 4, y: 2)
                        }
                        .padding(24)
                        .accessibilityLabel(
                            String(localized: "Scan barcode", comment: "Barcodes tab: floating scan button")
                        )
                        .accessibilityHint(
                            String(
                                localized: "Opens the barcode scanner camera",
                                comment: "Barcodes tab: floating scan button hint"
                            )
                        )
                        .accessibilityIdentifier("scan-barcode-button")
                    }
                }
                .fullScreenCover(
                    isPresented: $showScanner,
                    onDismiss: {
                        if let barcode = pendingBarcode {
                            selectedBarcode = barcode
                            pendingBarcode = nil
                        }
                    },
                    content: {
                        ScannerView(onSave: { barcode in
                            pendingBarcode = barcode
                        })
                    }
                )
            }
            .accessibilityIdentifier("tab-barcodes")

            Tab("Create", systemImage: "wand.and.stars", value: 1) {
                GeneratorView(onSave: { barcode in
                    pendingBarcode = barcode
                    selectedTab = 0
                })
            }
            .accessibilityIdentifier("tab-create")

            Tab("Map", systemImage: "map", value: 2) {
                MapView()
            }
            .accessibilityIdentifier("tab-map")

            Tab("Settings", systemImage: "gear", value: 3) {
                SettingsView()
            }
            .accessibilityIdentifier("tab-settings")
        }
        .tabViewStyle(.tabBarOnly)
        .onChange(of: pendingSharedImageScan) {
            if pendingSharedImageScan {
                selectedTab = 0
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0, let barcode = pendingBarcode {
                selectedBarcode = barcode
                pendingBarcode = nil
            }
        }
        .onChange(of: pendingQuickAction) { _, action in
            guard let action else { return }
            consumeQuickAction()
            showScanner = false
            switch action {
            case .scan:
                selectedTab = 0
                showScanner = true
            case .generate:
                selectedTab = 1
            case .favorites:
                selectedTab = 0
                filterFavorites = true
            }
        }
    }
}
