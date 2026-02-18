import SwiftUI

struct ContentView: View {
    @Binding var pendingSharedImageScan: Bool
    @State private var showScanner = false
    @State private var pendingBarcode: ScannedBarcode?
    @State private var selectedBarcode: ScannedBarcode?
    @State private var selectedTab = 0
    @State private var isSelectMode = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Barcodes", systemImage: "barcode.viewfinder", value: 0) {
                HistoryView(
                    selectedBarcode: $selectedBarcode,
                    isSelectMode: $isSelectMode,
                    pendingSharedImageScan: $pendingSharedImageScan
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

            Tab("Create", systemImage: "wand.and.stars", value: 1) {
                GeneratorView(onSave: { barcode in
                    pendingBarcode = barcode
                    selectedTab = 0
                })
            }

            Tab("Map", systemImage: "map", value: 2) {
                MapView()
            }

            Tab("Settings", systemImage: "gear", value: 3) {
                SettingsView()
            }
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
    }
}
