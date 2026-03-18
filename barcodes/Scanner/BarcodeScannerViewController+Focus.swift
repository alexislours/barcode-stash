@preconcurrency import AVFoundation
import UIKit

// MARK: - Tap-to-Focus

extension BarcodeScannerViewController {
    func setupFocusReticle() {
        let reticle = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        reticle.layer.borderColor = UIColor.systemYellow.cgColor
        reticle.layer.borderWidth = 1.5
        reticle.layer.cornerRadius = 2
        reticle.alpha = 0
        reticle.isUserInteractionEnabled = false
        view.addSubview(reticle)
        focusReticleView = reticle
    }

    func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        guard let device = videoDevice,
              let previewLayer,
              device.isFocusPointOfInterestSupported
        else { return }

        let screenPoint = gesture.location(in: view)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: screenPoint)

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = devicePoint
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {}

        showFocusReticle(at: screenPoint)
        scheduleFocusReset()
    }

    private func showFocusReticle(at point: CGPoint) {
        guard let reticle = focusReticleView else { return }
        reticle.center = point
        reticle.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        reticle.alpha = 1.0
        reticle.layer.removeAllAnimations()

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            reticle.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseIn) {
            reticle.alpha = 0
        }
    }

    private func scheduleFocusReset() {
        focusResetTimer?.invalidate()
        focusResetTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resetFocusToContinuous()
            }
        }
    }

    func subjectAreaChanged() {
        resetFocusToContinuous()
    }

    private func resetFocusToContinuous() {
        focusResetTimer?.invalidate()
        focusResetTimer = nil

        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {}

        if let reticle = focusReticleView, reticle.alpha > 0 {
            UIView.animate(withDuration: 0.2) {
                reticle.alpha = 0
            }
        }
    }
}
