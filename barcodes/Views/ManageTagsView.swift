import SwiftData
import SwiftUI

struct ManageTagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BarcodeTag.order) private var tags: [BarcodeTag]
    @Query private var barcodes: [ScannedBarcode]
    @State private var showAddSheet = false
    @State private var editingTag: BarcodeTag?
    @State private var tagToDelete: BarcodeTag?

    private var usageCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for barcode in barcodes {
            for tag in barcode.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    var body: some View {
        List {
            Section {
                ForEach(tags) { tag in
                    Button {
                        editingTag = tag
                    } label: {
                        tagRow(tag)
                    }
                    .tint(.primary)
                }
                .onDelete(perform: deleteTags)
                .onMove(perform: moveTags)
            } header: {
                if !tags.isEmpty {
                    Text("Tags", comment: "Manage tags: section header for managed tags")
                }
            }
        }
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView {
                    Label(
                        String(localized: "No Tags", comment: "Manage tags: empty state title"),
                        systemImage: "tag"
                    )
                } description: {
                    Text("Create tags to organize your barcodes.", comment: "Manage tags: empty state description")
                } actions: {
                    Button(String(localized: "Add tag", comment: "Manage tags: empty state add button")) {
                        showAddSheet = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .alert(
            String(localized: "Delete Tag?", comment: "Manage tags: delete confirmation title"),
            isPresented: Binding(
                get: { tagToDelete != nil },
                set: { if !$0 { tagToDelete = nil } }
            )
        ) {
            Button(String(localized: "Delete", comment: "Manage tags: delete confirmation button"), role: .destructive) {
                if let tag = tagToDelete {
                    confirmDelete(tag)
                    tagToDelete = nil
                }
            }
            Button(String(localized: "Cancel", comment: "Manage tags: cancel delete button"), role: .cancel) {
                tagToDelete = nil
            }
        } message: {
            if let tag = tagToDelete {
                let count = usageCounts[tag.name] ?? 0
                if count > 0 {
                    Text(
                        "This will remove \"\(tag.name)\" from \(count) barcode(s).",
                        comment: "Manage tags: delete confirmation message with usage count"
                    )
                } else {
                    Text(
                        "This will delete the \"\(tag.name)\" tag.",
                        comment: "Manage tags: delete confirmation message for unused tag"
                    )
                }
            }
        }
        .navigationTitle(String(localized: "Manage Tags", comment: "Manage tags: navigation title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Add tag", comment: "Manage tags: add tag button"))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            TagFormSheet(
                existingNames: Set(tags.map(\.name)),
                onSave: { name, colorName in
                    let tag = BarcodeTag(
                        name: name.lowercased(),
                        colorName: colorName,
                        order: (tags.map(\.order).max() ?? -1) + 1
                    )
                    modelContext.insert(tag)
                    try? modelContext.save()
                }
            )
        }
        .sheet(item: $editingTag) { tag in
            TagFormSheet(
                existingNames: Set(tags.map(\.name).filter { $0 != tag.name }),
                name: tag.name,
                colorName: tag.colorName,
                onSave: { name, colorName in
                    let oldName = tag.name
                    let newName = name.lowercased()
                    tag.name = newName
                    tag.colorName = colorName

                    // Rename tag on all barcodes if name changed
                    if oldName != newName {
                        for barcode in barcodes where barcode.tags.contains(oldName) {
                            barcode.tags = barcode.tags.map { $0 == oldName ? newName : $0 }
                            barcode.lastModified = .now
                        }
                    }
                    try? modelContext.save()
                }
            )
        }
    }

    private func tagRow(_ tag: BarcodeTag) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tag.color)
                .frame(width: 12, height: 12)

            Text(tag.name)

            Spacer()

            let count = usageCounts[tag.name] ?? 0
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        tagToDelete = tags[index]
    }

    private func confirmDelete(_ tag: BarcodeTag) {
        for barcode in barcodes where barcode.tags.contains(tag.name) {
            barcode.tags.removeAll { $0 == tag.name }
            barcode.lastModified = .now
        }
        modelContext.delete(tag)
        try? modelContext.save()
    }

    private func moveTags(from source: IndexSet, to destination: Int) {
        var ordered = tags
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, tag) in ordered.enumerated() {
            tag.order = index
        }
        try? modelContext.save()
    }
}

// MARK: - Tag Form Sheet

struct TagFormSheet: View {
    let existingNames: Set<String>
    var onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: String

    private var isEditing: Bool

    init(
        existingNames: Set<String>,
        name: String = "",
        colorName: String = TagPalette.curated[0].name,
        onSave: @escaping (String, String) -> Void
    ) {
        self.existingNames = existingNames
        self.onSave = onSave
        isEditing = !name.isEmpty
        _name = State(initialValue: name)
        _selectedColor = State(initialValue: colorName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSave: Bool {
        let trimmed = trimmedName
        return !trimmed.isEmpty && !existingNames.contains(trimmed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        TagChipView(
                            tag: trimmedName.isEmpty ? "preview" : trimmedName,
                            color: TagPalette.color(for: selectedColor)
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section(String(localized: "Name", comment: "Tag form: name section header")) {
                    TextField(
                        String(localized: "Tag name", comment: "Tag form: name field placeholder"),
                        text: $name
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                Section(String(localized: "Color", comment: "Tag form: color section header")) {
                    colorPicker
                }
            }
            .navigationTitle(
                isEditing
                    ? String(localized: "Edit Tag", comment: "Tag form: edit mode navigation title")
                    : String(localized: "New Tag", comment: "Tag form: create mode navigation title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Tag form: cancel button")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", comment: "Tag form: save button")) {
                        onSave(trimmedName, selectedColor)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(TagPalette.curated, id: \.name) { palette in
                Button {
                    selectedColor = palette.name
                } label: {
                    Circle()
                        .fill(TagPalette.color(for: palette.name))
                        .frame(width: 36, height: 36)
                        .overlay {
                            if selectedColor == palette.name {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                Circle()
                                    .strokeBorder(TagPalette.color(for: palette.name), lineWidth: 1)
                                    .padding(-3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(palette.label)
                .accessibilityAddTraits(selectedColor == palette.name ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
