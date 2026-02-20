import SwiftUI

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    @Binding var zoomFactor: CGFloat
    var restartCount: Int
    var continuousMode: Bool = false
    var allowedBarcodeTypes: Set<BarcodeType> = Set(BarcodeType.allCases)
    var onBarcodeScanned: (String, BarcodeType, Data?) -> Void
    var onBarcodeBoundsDetected: ((CGRect) -> Void)?
    var onZoomChanged: (CGFloat) -> Void
    var onZoomPresetsAvailable: ([ZoomPreset]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context _: Context) -> BarcodeScannerViewController {
        let viewController = BarcodeScannerViewController()
        viewController.onBarcodeScanned = onBarcodeScanned
        viewController.onBarcodeBoundsDetected = onBarcodeBoundsDetected
        viewController.onZoomChanged = onZoomChanged
        viewController.onSetupComplete = onZoomPresetsAvailable
        viewController.continuousMode = continuousMode
        viewController.allowedTypes = allowedBarcodeTypes.map(\.metadataObjectType)
        return viewController
    }

    func updateUIViewController(_ viewController: BarcodeScannerViewController, context: Context) {
        viewController.continuousMode = continuousMode
        viewController.onBarcodeScanned = onBarcodeScanned
        viewController.onBarcodeBoundsDetected = onBarcodeBoundsDetected
        viewController.setTorch(isTorchOn)
        viewController.setZoom(zoomFactor)

        let newTypes = allowedBarcodeTypes.map(\.metadataObjectType)
        if Set(newTypes) != Set(viewController.allowedTypes) {
            viewController.updateAllowedTypes(newTypes)
        }

        if context.coordinator.lastRestartCount != restartCount {
            context.coordinator.lastRestartCount = restartCount
            viewController.clearScannedKeys()
            viewController.startRunning()
        }
    }

    class Coordinator {
        var lastRestartCount = 0
    }
}
