import SwiftData
import SwiftUI

struct TagPickerSheet: View {
    @Bindable var barcode: ScannedBarcode
    let tagDefinitions: [BarcodeTag]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateTag = false

    var body: some View {
        NavigationStack {
            List {
                if !tagDefinitions.isEmpty {
                    Section {
                        ForEach(tagDefinitions) { tag in
                            Button {
                                toggleTag(tag.name)
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 12, height: 12)

                                    Text(tag.name)

                                    Spacer()

                                    if barcode.tags.contains(tag.name) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                Section {
                    Button {
                        showCreateTag = true
                    } label: {
                        Label(
                            String(localized: "New Tag", comment: "Tag picker: create new tag button"),
                            systemImage: "plus"
                        )
                    }

                    NavigationLink {
                        ManageTagsView()
                    } label: {
                        Label(
                            String(localized: "Manage Tags", comment: "Tag picker: manage tags link"),
                            systemImage: "tag"
                        )
                    }
                }
            }
            .navigationTitle(String(localized: "Tags", comment: "Tag picker: navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", comment: "Tag picker: done button")) { dismiss() }
                }
            }
            .sheet(isPresented: $showCreateTag) {
                TagFormSheet(
                    existingNames: Set(tagDefinitions.map(\.name)),
                    onSave: { name, colorName in
                        let order = (tagDefinitions.map(\.order).max() ?? -1) + 1
                        let tag = BarcodeTag(name: name, colorName: colorName, order: order)
                        modelContext.insert(tag)
                        try? modelContext.save()
                        if !barcode.tags.contains(name) {
                            barcode.tags.append(name)
                            barcode.lastModified = .now
                        }
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleTag(_ tagName: String) {
        withAccessibleAnimation {
            if barcode.tags.contains(tagName) {
                barcode.tags.removeAll { $0 == tagName }
            } else {
                barcode.tags.append(tagName)
            }
            barcode.lastModified = .now
        }
    }
}
