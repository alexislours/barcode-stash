import AVFoundation
import CoreLocation
import SwiftData
import SwiftUI

struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scannedValue: String?
    @State private var scannedType: BarcodeType?
    @State private var scannedDescriptorArchive: Data?
    @State private var locationManager = LocationManager()
    @State private var isTorchOn = false
    @State private var zoomFactor: CGFloat = 1.0
    @State private var zoomPresets: [ZoomPreset] = [ZoomPreset(factor: 1.0, label: "1x")]
    @State private var restartCount = 0
    @State private var allowedTypes: Set<BarcodeType> = Set(BarcodeType.allCases)

    // Scan animation
    @State private var barcodeBounds: CGRect?
    @State private var showScanResult = false

    /// Duplicate detection
    @State private var duplicateBarcode: ScannedBarcode?

    // Bulk mode
    @State private var isBulkMode = false
    @State private var bulkSessionScanned: Set<String> = []
    @State private var bulkSavedCount = 0
    @State private var bulkSkippedCount = 0
    @State private var bulkCooldowns: [String: Date] = [:]
    @State private var lastBulkBarcode: ScannedBarcode?

    @State private var viewSize: CGSize = .zero

    var onSave: ((ScannedBarcode) -> Void)?

    private var hasOverlayCard: Bool {
        showScanResult
    }

    private var isScreenshotMode: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("--screenshots")
        #else
            false
        #endif
    }

    private var isCameraDenied: Bool {
        cameraStatus == .denied || cameraStatus == .restricted
    }

    private var screenshotBackground: UIImage? {
        #if DEBUG
            guard let arg = ProcessInfo.processInfo.arguments.first(where: {
                $0.hasPrefix("--screenshot-bg=")
            }) else { return nil }
            let path = String(arg.dropFirst("--screenshot-bg=".count))
            return UIImage(contentsOfFile: path)
        #else
            return nil
        #endif
    }

    private var cameraDeniedView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .frame(minWidth: 44, minHeight: 44)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            ContentUnavailableView {
                Label(
                    String(localized: "Camera Access Required", comment: "Scanner: camera denied title"),
                    systemImage: "camera.fill"
                )
            } description: {
                Text("Allow camera access in Settings to scan barcodes.",
                     comment: "Scanner: camera denied description")
            } actions: {
                Button(String(localized: "Open Settings", comment: "Scanner: camera denied open settings button")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Spacer()
        }
        .environment(\.colorScheme, .dark)
    }

    var body: some View {
        ZStack {
            if isScreenshotMode {
                if let backgroundImage = screenshotBackground {
                    GeometryReader { geo in
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                } else {
                    Color(white: 0.06)
                        .ignoresSafeArea()
                }
            } else if isCameraDenied {
                Color.black
                    .ignoresSafeArea()
            } else {
                BarcodeScannerRepresentable(
                    isTorchOn: $isTorchOn,
                    zoomFactor: $zoomFactor,
                    restartCount: restartCount,
                    continuousMode: isBulkMode,
                    allowedBarcodeTypes: allowedTypes,
                    onBarcodeScanned: handleScan,
                    onBarcodeBoundsDetected: { barcodeBounds = $0 },
                    onZoomChanged: { zoomFactor = $0 },
                    onZoomPresetsAvailable: { zoomPresets = $0 }
                )
                .ignoresSafeArea()
            }

            if isCameraDenied {
                cameraDeniedView
            } else {
                VStack {
                    ScannerControlBar(
                        isBulkMode: $isBulkMode,
                        isTorchOn: $isTorchOn,
                        allowedTypes: $allowedTypes,
                        bulkSavedCount: bulkSavedCount,
                        hasOverlayCard: hasOverlayCard,
                        onDismiss: { dismiss() }
                    )

                    Spacer()

                    if scannedValue == nil || isBulkMode, zoomPresets.count > 1 {
                        ScannerZoomButtons(presets: zoomPresets, zoomFactor: $zoomFactor)
                            .padding(.bottom, isBulkMode && bulkSavedCount > 0 ? 12 : 40)
                    }

                    if isBulkMode, bulkSavedCount > 0 || bulkSkippedCount > 0 {
                        ScannerBulkCountBadge(savedCount: bulkSavedCount, skippedCount: bulkSkippedCount)
                            .padding(.bottom, 40)
                    }
                }

                ScannerResultOverlay(
                    showScanResult: showScanResult,
                    isBulkMode: isBulkMode,
                    scannedValue: scannedValue,
                    scannedType: scannedType,
                    scannedDescriptorArchive: scannedDescriptorArchive,
                    duplicateBarcode: duplicateBarcode,
                    barcodeBounds: barcodeBounds,
                    location: locationManager.lastLocation,
                    onSave: onSave,
                    onDismiss: { dismiss() },
                    onResetScan: resetScan
                )
            }
        }
        .onAppear(perform: resetScannerState)
        .statusBarHidden()
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            viewSize = newSize
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
        .task {
            guard isScreenshotMode else { return }
            await simulateScreenshotScan()
        }
    }

    // MARK: - Lifecycle

    private func resetScannerState() {
        if !isScreenshotMode {
            locationManager.requestPermission()
        }
        barcodeBounds = nil
        showScanResult = false
        bulkSessionScanned.removeAll()
        bulkSavedCount = 0
        bulkSkippedCount = 0
        bulkCooldowns.removeAll()
        lastBulkBarcode = nil
    }

    // MARK: - Screenshot Mode

    private func simulateScreenshotScan() async {
        try? await Task.sleep(for: .seconds(0.5))
        scannedValue = "5901234123457"
        scannedType = .ean13
        barcodeBounds = CGRect(
            x: viewSize.width / 2 - 110,
            y: viewSize.height * 0.35,
            width: 220,
            height: 70
        )
        try? await Task.sleep(for: .seconds(0.3))
        withAccessibleAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            showScanResult = true
        }
    }

    // MARK: - Scan Handling

    private func handleScan(value: String, type: BarcodeType, descriptorArchive: Data?) {
        if isBulkMode {
            handleBulkScan(value: value, type: type, descriptorArchive: descriptorArchive)
        } else {
            scannedValue = value
            scannedType = type
            scannedDescriptorArchive = descriptorArchive
            duplicateBarcode = existingBarcode(rawValue: value, type: type)
            locationManager.requestLocation()

            Task {
                try? await Task.sleep(for: .seconds(0.35))
                withAccessibleAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                    showScanResult = true
                }
            }
        }
    }

    // MARK: - Bulk Mode

    private func handleBulkScan(value: String, type: BarcodeType, descriptorArchive: Data?) {
        let key = "\(type.rawValue)|\(value)"

        // Check per-barcode cooldown (1.5s)
        if let lastSeen = bulkCooldowns[key], Date.now.timeIntervalSince(lastSeen) < 1.5 {
            return
        }
        bulkCooldowns[key] = .now

        // Only save if not already saved this session
        guard !bulkSessionScanned.contains(key) else { return }
        bulkSessionScanned.insert(key)

        // Skip if already exists in database
        if existingBarcode(rawValue: value, type: type) != nil {
            bulkSkippedCount += 1
            return
        }

        locationManager.requestLocation()
        let barcode = saveBarcode(value: value, type: type, descriptorArchive: descriptorArchive)
        lastBulkBarcode = barcode
        bulkSavedCount += 1

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Actions

    @discardableResult
    private func saveBarcode(
        value: String,
        type: BarcodeType,
        descriptorArchive: Data? = nil
    ) -> ScannedBarcode {
        let barcode = ScannedBarcode(
            rawValue: value,
            type: type,
            latitude: locationManager.lastLocation?.coordinate.latitude,
            longitude: locationManager.lastLocation?.coordinate.longitude,
            descriptorArchive: descriptorArchive ?? scannedDescriptorArchive
        )
        modelContext.insert(barcode)
        if let lat = barcode.latitude, let lon = barcode.longitude {
            let barcodeID = barcode.persistentModelID
            Task {
                let address = await ReverseGeocoder.reverseGeocode(
                    latitude: lat,
                    longitude: lon
                )
                guard let existing = modelContext.model(for: barcodeID) as? ScannedBarcode else { return }
                existing.address = address
            }
        }
        return barcode
    }

    private func resetScan() {
        withAccessibleAnimation(.easeOut(duration: 0.25)) {
            showScanResult = false
        }
        Task {
            try? await Task.sleep(for: .seconds(0.25))
            scannedValue = nil
            scannedType = nil
            scannedDescriptorArchive = nil
            duplicateBarcode = nil
            barcodeBounds = nil
            restartCount += 1
        }
    }

    private func existingBarcode(rawValue: String, type: BarcodeType) -> ScannedBarcode? {
        let descriptor = FetchDescriptor<ScannedBarcode>(
            predicate: #Predicate { barcode in
                barcode.rawValue == rawValue
            }
        )
        return try? modelContext.fetch(descriptor).first { $0.type == type }
    }
}
