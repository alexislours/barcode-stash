import SwiftUI

struct ScannerBulkCountBadge: View {
    let savedCount: Int
    let skippedCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(savedCount) saved")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            if skippedCount > 0 {
                Text("·")
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(skippedCount) skipped")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.6), in: Capsule())
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        if skippedCount > 0 {
            String(
                localized: "\(savedCount) saved, \(skippedCount) skipped",
                comment: "Scanner: bulk mode count badge with skipped"
            )
        } else {
            String(
                localized: "\(savedCount) saved",
                comment: "Scanner: bulk mode count badge"
            )
        }
    }
}
