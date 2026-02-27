@preconcurrency import AVFoundation
import CoreImage
import UIKit

struct ZoomPreset: Equatable {
    let factor: CGFloat // actual device videoZoomFactor
    let label: String // user-facing label (e.g. ".5", "1x", "5x")
}

final class BarcodeScannerViewController: UIViewController {
    var onBarcodeScanned: ((String, BarcodeType, Data?) -> Void)?
    var onBarcodeBoundsDetected: ((CGRect) -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?
    var onSetupComplete: (([ZoomPreset]) -> Void)?
    var continuousMode = false
    var allowedTypes: [AVMetadataObject.ObjectType] = [
        .qr, .ean13, .ean8, .upce,
        .code128, .code39, .code93,
        .pdf417, .aztec, .dataMatrix, .itf14,
    ]

    private nonisolated(unsafe) let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "barcode.scanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var videoDevice: AVCaptureDevice?
    private var lastZoomFactor: CGFloat = 1.0
    private var desiredTorchOn = false
    private var rampTargetFactor: CGFloat?

    // Focus
    private var focusReticleView: UIView?
    private var focusResetTimer: Timer?

    // Zoom haptics
    private var lensSwitchOverFactors: [CGFloat] = []
    private var lastLensIndex = 0

    private var highlightView: UIView?
    private var highlightPool: [UIView] = []
    private var continuousScannedKeys: Set<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraAccessAndSetup()
        setupHighlightView()
        setupFocusReticle()

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(subjectAreaDidChange),
            name: AVCaptureDevice.subjectAreaDidChangeNotification, object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        stopRunning()
    }

    @objc private func appWillEnterForeground() {
        if isViewLoaded, view.window != nil {
            startRunning()
        }
    }

    private func checkCameraAccessAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    Task { @MainActor [weak self] in
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        focusResetTimer?.invalidate()
        focusResetTimer = nil
        stopRunning()
    }

    func clearScannedKeys() {
        continuousScannedKeys.removeAll()
    }

    func startRunning() {
        hideHighlight(animated: false)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !captureSession.isRunning {
                captureSession.startRunning()
                Task { @MainActor [weak self] in
                    self?.applyTorch()
                }
            }
        }
    }

    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    func setTorch(_ enabled: Bool) {
        desiredTorchOn = enabled
        applyTorch()
    }

    private func applyTorch() {
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = desiredTorchOn ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }

    func setZoom(_ factor: CGFloat, animated: Bool = false) {
        guard let device = videoDevice else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 20.0)
        let clamped = min(max(factor, 1.0), maxZoom)
        if let target = rampTargetFactor, abs(target - clamped) <= 0.01 {
            return
        }
        guard abs(device.videoZoomFactor - clamped) > 0.01 else { return }
        do {
            try device.lockForConfiguration()
            if animated, !UIAccessibility.isReduceMotionEnabled {
                let distance = abs(clamped - device.videoZoomFactor)
                let rate = Float(max(1.0, min(distance / 0.3, 50.0)))
                device.ramp(toVideoZoomFactor: clamped, withRate: rate)
                rampTargetFactor = clamped
            } else {
                device.videoZoomFactor = clamped
                rampTargetFactor = nil
            }
            device.unlockForConfiguration()
        } catch {}
        checkLensSwitchHaptic(for: clamped)
    }

    func updateAllowedTypes(_ types: [AVMetadataObject.ObjectType]) {
        allowedTypes = types
        let output = metadataOutput
        sessionQueue.async {
            output?.metadataObjectTypes = types
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = videoDevice else { return }

        switch gesture.state {
        case .began:
            do {
                try device.lockForConfiguration()
                device.cancelVideoZoomRamp()
                device.unlockForConfiguration()
            } catch {}
            rampTargetFactor = nil
            lastZoomFactor = device.videoZoomFactor
        case .changed:
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 20.0)
            let desired = lastZoomFactor * pow(2.0, log2(max(gesture.scale, 0.01)))
            let clamped = min(max(desired, 1.0), maxZoom)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch { break }
            checkLensSwitchHaptic(for: clamped)
            onZoomChanged?(clamped)
        default:
            break
        }
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        let device: AVCaptureDevice? = {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInTripleCamera, .builtInDualWideCamera,
                    .builtInDualCamera, .builtInWideAngleCamera,
                ],
                mediaType: .video,
                position: .back
            )
            return discovery.devices.first
        }()

        guard let device, let input = try? AVCaptureDeviceInput(device: device) else { return }

        videoDevice = device

        captureSession.beginConfiguration()
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = allowedTypes
            metadataOutput = output
        }
        captureSession.commitConfiguration()

        do {
            try device.lockForConfiguration()
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {}

        lensSwitchOverFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { CGFloat(truncating: $0) }
        lastLensIndex = lensIndex(for: device.videoZoomFactor)

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        let presets = computeZoomPresets(for: device)
        Task { [weak self] in
            self?.onSetupComplete?(presets)
        }
    }

    private func lensIndex(for factor: CGFloat) -> Int {
        var index = 0
        for switchOver in lensSwitchOverFactors where factor >= switchOver {
            index += 1
        }
        return index
    }

    private func checkLensSwitchHaptic(for factor: CGFloat) {
        let newIndex = lensIndex(for: factor)
        if newIndex != lastLensIndex {
            lastLensIndex = newIndex
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func computeZoomPresets(for device: AVCaptureDevice) -> [ZoomPreset] {
        let hasUltraWide = device.deviceType == .builtInTripleCamera
            || device.deviceType == .builtInDualWideCamera

        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { CGFloat(truncating: $0) }

        if hasUltraWide {
            // Device zoom 1.0 = ultra-wide lens.
            // First switch-over = wide lens (the "1x" reference point).
            let wideZoom = switchOvers.first ?? 2.0
            var presets = [
                ZoomPreset(factor: 1.0, label: formatLabel(1.0 / wideZoom)),
                ZoomPreset(factor: wideZoom, label: "1x"),
            ]
            if switchOvers.count > 1 {
                let teleZoom = switchOvers[1]
                presets.append(ZoomPreset(factor: teleZoom, label: formatLabel(teleZoom / wideZoom)))
            }
            return presets
        } else {
            // Device zoom 1.0 = wide lens = "1x".
            var presets = [ZoomPreset(factor: 1.0, label: "1x")]
            if let switchOver = switchOvers.first {
                presets.append(ZoomPreset(factor: switchOver, label: formatLabel(switchOver)))
            }
            return presets
        }
    }

    private func formatLabel(_ value: CGFloat) -> String {
        if value < 1.0 {
            ".\(Int(round(value * 10)))"
        } else if value == value.rounded(.down) {
            "\(Int(value))x"
        } else {
            String(format: "%.1fx", value)
        }
    }
}

// MARK: - Tap-to-Focus

extension BarcodeScannerViewController {
    private func setupFocusReticle() {
        let reticle = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        reticle.layer.borderColor = UIColor.systemYellow.cgColor
        reticle.layer.borderWidth = 1.5
        reticle.layer.cornerRadius = 2
        reticle.alpha = 0
        reticle.isUserInteractionEnabled = false
        view.addSubview(reticle)
        focusReticleView = reticle
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
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

    @objc private func subjectAreaDidChange() {
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

// MARK: - Highlight

extension BarcodeScannerViewController {
    private func setupHighlightView() {
        let highlight = UIView()
        highlight.layer.cornerRadius = 8
        highlight.alpha = 0
        highlight.isUserInteractionEnabled = false
        view.addSubview(highlight)
        highlightView = highlight
    }

    private func showHighlight(at rect: CGRect) {
        guard let highlight = highlightView else { return }
        let color: UIColor = continuousMode ? .systemGreen : .systemYellow
        highlight.layer.borderColor = color.cgColor
        highlight.layer.borderWidth = 3
        highlight.backgroundColor = color.withAlphaComponent(0.15)

        let padded = rect.insetBy(dx: -8, dy: -8)
        highlight.frame = padded
        highlight.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        highlight.alpha = 0

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            highlight.alpha = 1
            highlight.transform = .identity
        }

        if continuousMode {
            UIView.animate(withDuration: 0.2, delay: 0.4, options: .curveEaseIn) {
                highlight.alpha = 0
            }
        }
    }

    private func showPooledHighlight(at rect: CGRect) {
        let highlight = highlightPool.first(where: { $0.alpha == 0 }) ?? makeHighlightView()
        let color: UIColor = .systemGreen
        highlight.layer.borderColor = color.cgColor
        highlight.layer.borderWidth = 3
        highlight.backgroundColor = color.withAlphaComponent(0.15)

        let padded = rect.insetBy(dx: -8, dy: -8)
        highlight.frame = padded
        highlight.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        highlight.alpha = 0

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            highlight.alpha = 1
            highlight.transform = .identity
        }
        UIView.animate(withDuration: 0.2, delay: 0.4, options: .curveEaseIn) {
            highlight.alpha = 0
        }
    }

    private func makeHighlightView() -> UIView {
        let highlight = UIView()
        highlight.layer.cornerRadius = 8
        highlight.alpha = 0
        highlight.isUserInteractionEnabled = false
        view.addSubview(highlight)
        highlightPool.append(highlight)
        return highlight
    }

    func hideHighlight(animated: Bool = true) {
        let allViews = [highlightView].compactMap(\.self) + highlightPool
        for highlight in allViews where highlight.alpha > 0 {
            if animated {
                UIView.animate(withDuration: 0.2) { highlight.alpha = 0 }
            } else {
                highlight.layer.removeAllAnimations()
                highlight.alpha = 0
            }
        }
    }
}

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
