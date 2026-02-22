import MapKit
import SwiftUI

struct ShareBarcodeSheet: View {
    let barcode: ScannedBarcode
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ShareMode = .simple
    @AppStorage("shareShowType") private var showType = true
    @AppStorage("shareShowRawValue") private var showRawValue = true
    @AppStorage("shareShowDescription") private var showDescription = true
    @AppStorage("shareShowDate") private var showDate = true
    @AppStorage("shareShowMap") private var showMap = true
    @AppStorage("shareShowAddress") private var showAddress = true
    @State private var barcodeImage: UIImage?
    @State private var mapSnapshot: UIImage?
    @State private var shareImage: Image?
    @AppStorage("mapStyle") private var mapStyle: MapStyleOption = .standard

    enum ShareMode: String, CaseIterable {
        case simple = "Simple"
        case card = "Card"

        var localizedName: String {
            switch self {
            case .simple: String(localized: "Simple", comment: "Share mode: simple barcode image")
            case .card: String(localized: "Card", comment: "Share mode: rich card layout")
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Mode", selection: $mode) {
                        ForEach(ShareMode.allCases, id: \.self) { shareMode in
                            Text(shareMode.localizedName).tag(shareMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("share-mode-picker")
                    .padding(.horizontal)

                    Group {
                        if mode == .simple {
                            simplePreview(barcodeImage: barcodeImage)
                        } else {
                            cardPreview(barcodeImage: barcodeImage)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    .padding(.horizontal)

                    if mode == .card {
                        toggleSection
                    }

                    ShareLink(
                        item: shareImage ?? Image(systemName: "barcode"),
                        preview: SharePreview(
                            barcode.rawValue,
                            image: shareImage ?? Image(systemName: "barcode")
                        )
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(shareImage == nil)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Share Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("share-done-button")
                }
            }
            .task {
                barcodeImage = BarcodeGenerator.generateImage(
                    for: barcode,
                    size: CGSize(width: 300, height: 300)
                )
                await loadMapSnapshot()
            }
            .task(id: shareRenderKey) {
                shareImage = renderShareImage(barcodeImage: barcodeImage)
            }
        }
    }

    // MARK: - Simple Preview

    private func simplePreview(barcodeImage: UIImage?) -> some View {
        VStack {
            if let barcodeImage {
                Image(uiImage: barcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 250)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    // MARK: - Card Preview

    private func cardPreview(barcodeImage: UIImage?) -> some View {
        ShareableBarcodeView(
            barcode: barcode,
            barcodeImage: barcodeImage,
            mapSnapshot: mapSnapshot,
            showDescription: showDescription,
            showRawValue: showRawValue,
            showType: showType,
            showDate: showDate,
            showMap: showMap && barcode.latitude != nil,
            showAddress: showAddress
        )
    }

    // MARK: - Toggles

    private var toggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Type", isOn: $showType)
            Toggle("Raw Value", isOn: $showRawValue)
            Toggle("Description", isOn: $showDescription)
            Toggle("Date", isOn: $showDate)
            if barcode.address != nil {
                Toggle("Address", isOn: $showAddress)
            }
            if barcode.latitude != nil {
                Toggle("Map", isOn: $showMap)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Render

    @MainActor
    private func renderShareImage(barcodeImage: UIImage?) -> Image {
        if mode == .simple {
            if let uiImage = renderSimple(barcodeImage: barcodeImage) {
                return Image(uiImage: uiImage)
            }
            return Image(systemName: "barcode")
        } else {
            let view = ShareableBarcodeView(
                barcode: barcode,
                barcodeImage: barcodeImage,
                mapSnapshot: mapSnapshot,
                showDescription: showDescription,
                showRawValue: showRawValue,
                showType: showType,
                showDate: showDate,
                showMap: showMap && barcode.latitude != nil,
                showAddress: showAddress
            )
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            if let uiImage = renderer.uiImage {
                return Image(uiImage: uiImage)
            }
            return Image(systemName: "barcode")
        }
    }

    @MainActor
    private func renderSimple(barcodeImage: UIImage?) -> UIImage? {
        guard let barcodeImage else { return nil }
        let padding: CGFloat = 40
        let size = CGSize(
            width: barcodeImage.size.width + padding * 2,
            height: barcodeImage.size.height + padding * 2
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            barcodeImage.draw(in: CGRect(
                x: padding, y: padding,
                width: barcodeImage.size.width,
                height: barcodeImage.size.height
            ))
        }
    }

    // MARK: - Share Render Key

    private var shareRenderKey: ShareRenderKey {
        ShareRenderKey(
            mode: mode,
            showType: showType,
            showRawValue: showRawValue,
            showDescription: showDescription,
            showDate: showDate,
            showMap: showMap,
            showAddress: showAddress,
            hasBarcodeImage: barcodeImage != nil,
            hasMapSnapshot: mapSnapshot != nil
        )
    }

    private struct ShareRenderKey: Hashable {
        let mode: ShareMode
        let showType: Bool
        let showRawValue: Bool
        let showDescription: Bool
        let showDate: Bool
        let showMap: Bool
        let showAddress: Bool
        let hasBarcodeImage: Bool
        let hasMapSnapshot: Bool
    }

    // MARK: - Map Snapshot

    private func loadMapSnapshot() async {
        guard let lat = barcode.latitude, let lon = barcode.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        switch mapStyle {
        case .standard: options.mapType = .standard
        case .satellite: options.mapType = .satellite
        case .hybrid: options.mapType = .hybrid
        }
        let snapshotSize = CGSize(width: 360, height: 140)
        options.size = snapshotSize
        options.scale = UITraitCollection.current.displayScale
        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return }

        let renderer = UIGraphicsImageRenderer(size: snapshotSize)
        mapSnapshot = renderer.image { _ in
            snapshot.image.draw(at: .zero)

            let point = snapshot.point(for: coordinate)
            let pinImage = UIImage(systemName: "mappin.circle.fill")?
                .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            let pinSize = CGSize(width: 30, height: 30)
            pinImage?.draw(in: CGRect(
                x: point.x - pinSize.width / 2,
                y: point.y - pinSize.height / 2,
                width: pinSize.width,
                height: pinSize.height
            ))
        }
    }
}
