import AVFoundation
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
    private nonisolated(unsafe) var metadataOutput: AVCaptureMetadataOutput?
    private var videoDevice: AVCaptureDevice?
    private var lastZoomFactor: CGFloat = 1.0
    private var desiredTorchOn = false
    private var highlightView: UIView?
    private var highlightPool: [UIView] = []
    private var continuousScannedKeys: Set<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraAccessAndSetup()
        setupHighlightView()

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
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
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
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
                DispatchQueue.main.async { [weak self] in
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

    func setZoom(_ factor: CGFloat) {
        guard let device = videoDevice else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 20.0)
        let clamped = min(max(factor, 1.0), maxZoom)
        guard abs(device.videoZoomFactor - clamped) > 0.01 else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {}
    }

    func updateAllowedTypes(_ types: [AVMetadataObject.ObjectType]) {
        allowedTypes = types
        sessionQueue.async { [weak self] in
            guard let output = self?.metadataOutput else { return }
            output.metadataObjectTypes = types
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = videoDevice else { return }

        switch gesture.state {
        case .began:
            lastZoomFactor = device.videoZoomFactor
        case .changed:
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 20.0)
            let desired = lastZoomFactor * gesture.scale
            let clamped = min(max(desired, 1.0), maxZoom)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch { break }
            onZoomChanged?(clamped)
        default:
            break
        }
    }

    // MARK: - Highlight

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

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        let presets = computeZoomPresets(for: device)
        DispatchQueue.main.async { [weak self] in
            self?.onSetupComplete?(presets)
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
