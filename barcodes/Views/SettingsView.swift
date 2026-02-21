import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedBarcode.timestamp, order: .reverse) private var barcodes: [ScannedBarcode]

    @State private var showImporter = false
    @State private var exportFileURL: URL?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showDeleteConfirmation = false
    @AppStorage("mapStyle") private var mapStyle: MapStyleOption = .standard
    @AppStorage("showAdvancedData") private var showAdvancedData = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("iCloud Sync", systemImage: "checkmark.icloud")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Barcodes sync automatically across your devices via iCloud.")
                }

                Section {
                    Picker(selection: $mapStyle) {
                        ForEach(MapStyleOption.allCases, id: \.self) { option in
                            Label(option.localizedName, systemImage: option.icon)
                        }
                    } label: {
                        Label("Map Style", systemImage: "map")
                    }

                    Toggle(isOn: $showAdvancedData) {
                        Label("Advanced Data", systemImage: "tablecells")
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text(
                        "Show raw metadata like symbology details and descriptor archives on the barcode detail screen."
                    )
                }

                Section {
                    Menu {
                        Button("JSON", systemImage: "curlybraces") { exportBarcodes(format: .json) }
                        Button("CSV", systemImage: "tablecells") { exportBarcodes(format: .csv) }
                    } label: {
                        Label("Export Barcodes", systemImage: "square.and.arrow.up")
                    }
                    .disabled(barcodes.isEmpty)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Barcodes", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("\(barcodes.count) barcodes stored")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All Barcodes", systemImage: "trash")
                    }
                    .disabled(barcodes.isEmpty)
                }

                Section {
                    if let url = URL(string: "https://github.com/alexislours/barcode-stash") {
                        Link(destination: url) {
                            Label {
                                Text("GitHub Repository")
                            } icon: {
                                Image("github")
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                    }
                } footer: {
                    let version =
                        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
                    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
                    Text("Version \(version) (\(build))")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $exportFileURL) { url in
                ShareSheetView(items: [url])
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case let .success(url):
                    importBarcodes(from: url)
                case let .failure(error):
                    showResult(
                        title: String(localized: "Import Failed", comment: "Alert title when barcode import fails"),
                        message: error.localizedDescription
                    )
                }
            }
            .alert("Delete All Barcodes", isPresented: $showDeleteConfirmation) {
                Button("Delete All", role: .destructive) {
                    deleteAllBarcodes()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(barcodes.count) barcodes. This cannot be undone.")
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func exportBarcodes(format: ExportFormat) {
        do {
            exportFileURL = try ExportableBarcode.exportToFile(barcodes, format: format)
        } catch {
            showResult(
                title: String(localized: "Export Failed", comment: "Alert title when barcode export fails"),
                message: error.localizedDescription
            )
        }
    }

    private func deleteAllBarcodes() {
        do {
            for barcode in barcodes {
                modelContext.delete(barcode)
            }
            try modelContext.save()
            BarcodeImageCache.shared.removeAll()
            ReverseGeocoder.clearCache()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } catch {
            showResult(
                title: String(localized: "Delete Failed", comment: "Alert title when deleting all barcodes fails"),
                message: error.localizedDescription
            )
        }
    }

    private func importBarcodes(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showResult(
                title: String(localized: "Import Failed", comment: "Alert title when barcode import fails"),
                message: String(
                    localized: "Could not access the selected file.",
                    comment: "Error message when file access is denied during import"
                )
            )
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let imported = try decoder.decode([ExportableBarcode].self, from: data)

            var added = 0
            for item in imported {
                if let barcode = item.toScannedBarcode() {
                    let isDuplicate = barcodes.contains { existing in
                        existing.rawValue == barcode.rawValue
                            && existing.type == barcode.type
                            && abs(existing.timestamp.timeIntervalSince(barcode.timestamp)) < 1.0
                    }
                    if !isDuplicate {
                        modelContext.insert(barcode)
                        added += 1
                    }
                }
            }

            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let skipped = imported.count - added
            showResult(
                title: String(localized: "Import Successful"),
                message: String(localized: "Added \(added) new barcodes. \(skipped) duplicates skipped.")
            )
        } catch {
            showResult(
                title: String(localized: "Import Failed", comment: "Alert title when barcode import fails"),
                message: error.localizedDescription
            )
        }
    }

    private func showResult(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
