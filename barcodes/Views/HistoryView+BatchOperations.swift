import SwiftData
import SwiftUI
import UIKit

// MARK: - Batch Operations

extension HistoryView {
    var selectedBarcodes: [ScannedBarcode] {
        barcodes.filter { selectedBarcodeIDs.contains($0.persistentModelID) }
    }

    // MARK: - Select Button

    var selectButton: some View {
        Button {
            withAccessibleAnimation {
                if isEditing {
                    editMode = .inactive
                    selectedBarcodeIDs.removeAll()
                } else {
                    editMode = .active
                }
            }
        } label: {
            Text(
                isEditing
                    ? String(localized: "Done", comment: "History: exit selection mode")
                    : String(localized: "Select", comment: "History: enter selection mode")
            )
        }
        .disabled(barcodes.isEmpty)
        .accessibilityLabel(
            isEditing
                ? String(localized: "Done selecting", comment: "History: done selecting button")
                : String(localized: "Select barcodes", comment: "History: select barcodes button")
        )
        .accessibilityHint(
            isEditing
                ? String(localized: "Exits selection mode", comment: "History: done selecting hint")
                : String(
                    localized: "Enters selection mode for batch operations",
                    comment: "History: select barcodes hint"
                )
        )
    }

    // MARK: - Batch Toolbar

    var batchToolbar: some View {
        HStack {
            Button(role: .destructive) {
                showBatchDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .disabled(selectedBarcodeIDs.isEmpty)
            .accessibilityLabel(String(
                localized: "Delete selected",
                comment: "History: batch delete button"
            ))

            Spacer()

            Text("\(selectedBarcodeIDs.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                batchTagText = ""
                showBatchTagSheet = true
            } label: {
                Image(systemName: "tag")
            }
            .disabled(selectedBarcodeIDs.isEmpty)
            .accessibilityLabel(String(
                localized: "Tag selected",
                comment: "History: batch tag button"
            ))

            Menu {
                Button("JSON", systemImage: "curlybraces") { batchExport(format: .json) }
                Button("CSV", systemImage: "tablecells") { batchExport(format: .csv) }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(selectedBarcodeIDs.isEmpty)
            .accessibilityLabel(String(
                localized: "Export selected",
                comment: "History: batch export button"
            ))
        }
    }

    // MARK: - Batch Tag Sheet

    var batchTagSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tags (comma-separated)", text: $batchTagText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Tags will be added to \(selectedBarcodeIDs.count) selected barcodes.")
                }
            }
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBatchTagSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        batchTag()
                        showBatchTagSheet = false
                    }
                    .disabled(batchTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    func deleteBarcodes(at offsets: IndexSet, from source: [ScannedBarcode]) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let toDelete = offsets.map { source[$0] }
        for barcode in toDelete {
            modelContext.delete(barcode)
        }
    }

    func batchDelete() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        for barcode in selectedBarcodes {
            modelContext.delete(barcode)
        }
        finishBatchAction()
    }

    func batchExport(format: ExportFormat) {
        do {
            batchExportFileURL = try ExportableBarcode.exportToFile(selectedBarcodes, format: format)
        } catch {
            exportError = error.localizedDescription
        }
        finishBatchAction()
    }

    func batchTag() {
        let newTags = batchTagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        guard !newTags.isEmpty else { return }

        for barcode in selectedBarcodes {
            let existing = Set(barcode.tags)
            let toAdd = newTags.filter { !existing.contains($0) }
            if !toAdd.isEmpty {
                barcode.tags.append(contentsOf: toAdd)
                barcode.lastModified = .now
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        finishBatchAction()
    }

    func finishBatchAction() {
        withAccessibleAnimation {
            selectedBarcodeIDs.removeAll()
            editMode = .inactive
        }
    }
}
