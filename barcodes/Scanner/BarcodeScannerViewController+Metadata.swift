@preconcurrency import AVFoundation
import UIKit

// MARK: - Metadata Detection

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        if continuousMode {
            handleContinuousDetection(metadataObjects)
        } else {
            handleSingleDetection(metadataObjects)
        }
    }

    private func handleSingleDetection(_ metadataObjects: [AVMetadataObject]) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = metadata.stringValue,
              let type = BarcodeType(metadataType: metadata.type)
        else { return }

        var archive: Data?
        if let descriptor = metadata.descriptor {
            archive = try? NSKeyedArchiver.archivedData(withRootObject: descriptor, requiringSecureCoding: true)
        }

        if let transformed = previewLayer?.transformedMetadataObject(for: metadata) {
            showHighlight(at: transformed.bounds)
            onBarcodeBoundsDetected?(transformed.bounds)
        }

        stopRunning()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onBarcodeScanned?(value, type, archive)
    }

    private func handleContinuousDetection(_ metadataObjects: [AVMetadataObject]) {
        for object in metadataObjects {
            guard let metadata = object as? AVMetadataMachineReadableCodeObject,
                  let value = metadata.stringValue,
                  let type = BarcodeType(metadataType: metadata.type)
            else { continue }

            let key = "\(type.rawValue)|\(value)"
            guard !continuousScannedKeys.contains(key) else { continue }
            continuousScannedKeys.insert(key)

            var archive: Data?
            if let descriptor = metadata.descriptor {
                archive = try? NSKeyedArchiver.archivedData(withRootObject: descriptor, requiringSecureCoding: true)
            }

            if let transformed = previewLayer?.transformedMetadataObject(for: metadata) {
                showPooledHighlight(at: transformed.bounds)
                onBarcodeBoundsDetected?(transformed.bounds)
            }

            onBarcodeScanned?(value, type, archive)
        }
    }
}
