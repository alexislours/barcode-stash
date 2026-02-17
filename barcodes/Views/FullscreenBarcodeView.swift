import SwiftUI
import UIKit

struct FullscreenBarcodeView: View {
    let barcode: ScannedBarcode
    @Environment(\.dismiss) private var dismiss
    @State private var previousBrightness: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    private var currentScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .screen
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    let maxWidth = geometry.size.width - 40
                    let maxHeight = geometry.size.height * 0.5

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)

                        BarcodePreviewView(
                            barcode: barcode,
                            size: CGSize(width: maxWidth - 32, height: maxHeight - 32)
                        )
                        .padding(16)
                    }
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(barcode.rawValue)
                        .font(.title3.monospaced())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let description = barcode.barcodeDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()
                }
            }
            .offset(y: dragOffset)
        }
        .statusBarHidden()
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityLabel(
            String(localized: "Fullscreen barcode: \(barcode.rawValue)",
                   comment: "Fullscreen barcode view accessibility label")
        )
        .accessibilityHint(
            String(localized: "Tap or swipe down to dismiss",
                   comment: "Fullscreen barcode view accessibility hint")
        )
        .onTapGesture {
            dismiss()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    } else {
                        withAccessibleAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            if let screen = currentScreen {
                previousBrightness = screen.brightness
                screen.brightness = 1.0
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            currentScreen?.brightness = previousBrightness
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
