import SwiftData
import SwiftUI

struct BatchTagSheet: View {
    let selectedCount: Int
    var onApply: ([String]) -> Void
    var onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BarcodeTag.order) private var tagDefinitions: [BarcodeTag]
    @State private var selectedTags: Set<String> = []
    @State private var showCreateTag = false

    var body: some View {
        NavigationStack {
            List {
                if !tagDefinitions.isEmpty {
                    Section {
                        ForEach(tagDefinitions) { tag in
                            Button {
                                if selectedTags.contains(tag.name) {
                                    selectedTags.remove(tag.name)
                                } else {
                                    selectedTags.insert(tag.name)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 12, height: 12)

                                    Text(tag.name)

                                    Spacer()

                                    if selectedTags.contains(tag.name) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    } footer: {
                        Text(
                            "Tags will be added to \(selectedCount) selected barcodes.",
                            comment: "Batch tag: footer explaining how many barcodes are affected"
                        )
                    }
                }

                Section {
                    Button {
                        showCreateTag = true
                    } label: {
                        Label(
                            String(localized: "New Tag", comment: "Batch tag: create new tag button"),
                            systemImage: "plus"
                        )
                    }

                    NavigationLink {
                        ManageTagsView()
                    } label: {
                        Label(
                            String(localized: "Manage Tags", comment: "Batch tag: manage tags link"),
                            systemImage: "tag"
                        )
                    }
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
                        selectedTags.insert(name)
                    }
                )
            }
            .navigationTitle(String(localized: "Add Tags", comment: "Batch tag: navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Batch tag: cancel button")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add", comment: "Batch tag: confirm add button")) {
                        onApply(Array(selectedTags))
                    }
                    .disabled(selectedTags.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
