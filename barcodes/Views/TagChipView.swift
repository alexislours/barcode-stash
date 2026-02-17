import SwiftUI

struct TagChipView: View {
    let tag: String
    var removable: Bool = false
    var onRemove: (() -> Void)?

    private var chipColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let hash = abs(tag.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            if removable {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(chipColor.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(chipColor)
        .background(chipColor.opacity(0.12), in: Capsule())
    }
}
