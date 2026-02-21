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
            if isEditing {
                Image(systemName: "xmark")
            } else {
                Text(String(localized: "Select", comment: "History: enter selection mode"))
            }
        }
        .disabled(barcodes.isEmpty)
        .accessibilityLabel(
            isEditing
                ? String(localized: "Cancel selection", comment: "History: cancel selection mode button")
                : String(localized: "Select barcodes", comment: "History: select barcodes button")
        )
        .accessibilityHint(
            isEditing
                ? String(localized: "Exits selection mode", comment: "History: cancel selecting hint")
                : String(
                    localized: "Enters selection mode for batch operations",
                    comment: "History: select barcodes hint"
                )
        )
    }

    // MARK: - Editing Trailing Buttons

    var editingTagButton: some View {
        Button {
            batchTagText = ""
            showBatchTagSheet = true
        } label: {
            Image(systemName: "tag")
                .padding(8)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .circle)
        .disabled(selectedBarcodeIDs.isEmpty)
        .accessibilityLabel(String(
            localized: "Tag selected",
            comment: "History: batch tag button"
        ))
    }

    var editingSelectAllButton: some View {
        Button {
            withAccessibleAnimation {
                if isAllFilteredSelected {
                    selectedBarcodeIDs.removeAll()
                } else {
                    selectedBarcodeIDs = Set(filteredBarcodes.map(\.persistentModelID))
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(
                isAllFilteredSelected
                    ? String(localized: "Deselect All", comment: "History: deselect all button label")
                    : String(localized: "Select All", comment: "History: select all button label")
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .capsule)
    }

    // MARK: - Batch Toolbar

    var isAllFilteredSelected: Bool {
        !filteredBarcodes.isEmpty
            && filteredBarcodes.allSatisfy { selectedBarcodeIDs.contains($0.persistentModelID) }
    }

    var batchToolbar: some View {
        GlassEffectContainer {
            HStack {
                Button(role: .destructive) {
                    showBatchDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .padding(13)
                }
                .buttonStyle(.plain)
                .glassEffect(in: .circle)
                .disabled(selectedBarcodeIDs.isEmpty)
                .accessibilityLabel(String(
                    localized: "Delete selected",
                    comment: "History: batch delete button"
                ))

                Spacer()

                Group {
                    if selectedBarcodeIDs.isEmpty {
                        Text(
                            "Select Items",
                            comment: "History: no items selected in batch mode"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Text(
                            "\(selectedBarcodeIDs.count) Selected",
                            comment: "History: number of selected items in batch mode"
                        )
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .glassEffect(in: .capsule)

                Spacer()

                Menu {
                    Button("JSON", systemImage: "curlybraces") { batchExport(format: .json) }
                    Button("CSV", systemImage: "tablecells") { batchExport(format: .csv) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .padding(13)
                }
                .buttonStyle(.plain)
                .glassEffect(in: .circle)
                .disabled(selectedBarcodeIDs.isEmpty)
                .accessibilityLabel(String(
                    localized: "Export selected",
                    comment: "History: batch export button"
                ))
            }
            .padding(.horizontal)
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
