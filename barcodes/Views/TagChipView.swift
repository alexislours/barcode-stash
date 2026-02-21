import SwiftUI

struct TagChipView: View {
    let tag: String
    var removable: Bool = false
    var onRemove: (() -> Void)?

    private var chipColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        return colors[Self.stableHash(tag) % colors.count]
    }

    /// Deterministic djb2 hash
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Int(hash % UInt64(Int.max))
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
                .accessibilityLabel(String(localized: "Remove \(tag)", comment: "Tag chip: remove tag button"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(chipColor)
        .background(chipColor.opacity(0.12), in: Capsule())
    }
}
