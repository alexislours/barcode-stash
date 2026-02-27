import SwiftUI
import UIKit

struct ScannerZoomButtons: View {
    let presets: [ZoomPreset]
    @Binding var zoomFactor: CGFloat

    private var activePreset: ZoomPreset? {
        presets.min(by: { abs($0.factor - zoomFactor) < abs($1.factor - zoomFactor) })
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(presets, id: \.factor) { preset in
                let isSelected = preset == activePreset
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAccessibleAnimation(.snappy) {
                        zoomFactor = preset.factor
                    }
                } label: {
                    Text(preset.label)
                        .font(isSelected ? .caption.weight(.bold) : .caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(isSelected ? .yellow : .white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(isSelected ? .white.opacity(0.15) : .clear)
                        )
                        .animation(.snappy, value: isSelected)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
            }
        }
        .padding(.horizontal, 4)
        .background(.black.opacity(0.4), in: Capsule())
    }
}
