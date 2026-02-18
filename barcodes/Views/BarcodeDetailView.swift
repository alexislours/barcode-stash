import CoreImage
import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct BarcodeDetailView: View {
    @Bindable var barcode: ScannedBarcode
    @State private var descriptionText: String = ""
    @State private var showFullscreen = false
    @State private var newTagText = ""
    @State private var isAddingTag = false
    @FocusState private var tagFieldFocused: Bool
    @AppStorage("mapStyle") private var mapStyle: MapStyleOption = .standard
    @AppStorage("showAdvancedData") private var showAdvancedData = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showShareSheet = false
    @State private var locationManager = LocationManager()
    @State private var isCapturingLocation = false
    @State private var locationError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BarcodePreviewView(barcode: barcode, size: CGSize(width: 250, height: 250))
                    .padding(.top)
                    .onTapGesture {
                        showFullscreen = true
                    }
                    .accessibilityLabel(
                        String(
                            localized: "\(barcode.type.rawValue) barcode preview",
                            comment: "Detail: barcode image preview"
                        )
                    )
                    .accessibilityHint(
                        String(
                            localized: "Double-tap to view fullscreen",
                            comment: "Detail: barcode image preview hint"
                        )
                    )

                if let payload = BarcodePayloadParser.parse(rawValue: barcode.rawValue, type: barcode.type) {
                    BarcodeActionView(payload: payload)
                }

                VStack(spacing: 8) {
                    Text(barcode.type.localizedName)
                        .font(.title2.bold())

                    Text(barcode.rawValue)
                        .font(.body.monospaced())
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .padding(.horizontal)

                    Text(barcode.timestamp, format: .dateTime.month().day().year().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("Tap to add a note...", text: $descriptionText, axis: .vertical)
                        .lineLimit(1 ... 6)
                        .onChange(of: descriptionText) {
                            let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                            barcode.barcodeDescription = trimmed.isEmpty ? nil : trimmed
                            barcode.lastModified = .now
                        }
                }
                .padding(12)
                .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    FlowLayout(spacing: 6) {
                        ForEach(barcode.tags, id: \.self) { tag in
                            TagChipView(tag: tag, removable: true) {
                                withAccessibleAnimation {
                                    barcode.tags.removeAll { $0 == tag }
                                    barcode.lastModified = .now
                                }
                            }
                        }

                        if isAddingTag {
                            tagInputChip
                        } else {
                            Button {
                                newTagText = ""
                                isAddingTag = true
                                tagFieldFocused = true
                            } label: {
                                Label("Add Tag", systemImage: "plus")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.fill.tertiary, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Add tag", comment: "Detail: add tag button"))
                            .accessibilityHint(
                                String(
                                    localized: "Opens a text field to add a new tag",
                                    comment: "Detail: add tag button hint"
                                )
                            )
                            .accessibilityIdentifier("add-tag-button")
                        }
                    }
                }
                .padding(.horizontal)

                if let address = barcode.address {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                if let lat = barcode.latitude, let lon = barcode.longitude {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let region = MKCoordinateRegion(
                        center: coordinate,
                        latitudinalMeters: 500,
                        longitudinalMeters: 500
                    )
                    Map(position: $mapPosition) {
                        Marker("Scanned here", coordinate: coordinate)
                    }
                    .mapStyle(mapStyle.style)
                    .onAppear {
                        mapPosition = .region(region)
                    }
                    .onChange(of: mapStyle) {
                        mapPosition = .region(region)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .accessibilityLabel(
                        String(
                            localized: "Map showing scan location",
                            comment: "Detail: map showing where barcode was scanned"
                        )
                    )
                } else {
                    VStack(spacing: 8) {
                        Button {
                            captureCurrentLocation()
                        } label: {
                            // Localized explicitly - ternary result is String, not LocalizedStringKey
                            Label(
                                isCapturingLocation
                                    ? String(
                                        localized: "Getting Location...",
                                        comment: "Button label on detail screen while GPS coordinates are being fetched"
                                    )
                                    : String(
                                        localized: "Add Current Location",
                                        comment: "Button on barcode detail to capture GPS coordinates"
                                    ),
                                systemImage: isCapturingLocation ? "location.circle" : "location.fill"
                            )
                            .symbolEffect(.pulse, isActive: isCapturingLocation)
                        }
                        .disabled(isCapturingLocation)
                        .accessibilityLabel(
                            isCapturingLocation
                                ? String(localized: "Getting location", comment: "Detail: location capture in progress")
                                : String(localized: "Add current location", comment: "Detail: add location button")
                        )
                        .accessibilityHint(
                            String(
                                localized: "Captures your current GPS coordinates for this barcode",
                                comment: "Detail: add location button hint"
                            )
                        )

                        if let locationError {
                            VStack(spacing: 6) {
                                Text(locationError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)

                                Button("Retry") {
                                    captureCurrentLocation()
                                }
                                .font(.caption.weight(.medium))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                descriptorDataSection

                Spacer()
            }
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(String(localized: "Share barcode", comment: "Detail: share toolbar button"))
                .accessibilityIdentifier("share-barcode-button")

                Button {
                    barcode.isFavorite.toggle()
                    barcode.lastModified = .now
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: barcode.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(barcode.isFavorite ? .yellow : .gray)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(
                    barcode.isFavorite
                        ? String(localized: "Remove from favorites", comment: "Detail: unfavorite toolbar button")
                        : String(localized: "Add to favorites", comment: "Detail: favorite toolbar button")
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareBarcodeSheet(barcode: barcode)
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenBarcodeView(barcode: barcode)
        }
        .onAppear {
            descriptionText = barcode.barcodeDescription ?? ""
        }
        .onChange(of: locationManager.locationUpdateCount) {
            guard isCapturingLocation, let location = locationManager.lastLocation else { return }
            barcode.latitude = location.coordinate.latitude
            barcode.longitude = location.coordinate.longitude
            Task {
                barcode.address = await ReverseGeocoder.reverseGeocode(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            withAccessibleAnimation {
                isCapturingLocation = false
                locationError = nil
            }
        }
        .task {
            if barcode.address == nil, let lat = barcode.latitude, let lon = barcode.longitude {
                barcode.address = await ReverseGeocoder.reverseGeocode(latitude: lat, longitude: lon)
            }
        }
    }
}

// MARK: - Private Helpers

extension BarcodeDetailView {
    var tagInputChip: some View {
        TextField("tag", text: $newTagText)
            .font(.caption)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($tagFieldFocused)
            .frame(width: 80)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.fill.tertiary, in: Capsule())
            .onSubmit {
                commitTag()
            }
            .onChange(of: tagFieldFocused) {
                if !tagFieldFocused {
                    commitTag()
                }
            }
    }

    struct DescriptorRow {
        let label: String
        let value: String
    }

    func commitTag() {
        let trimmed = newTagText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !trimmed.isEmpty, !barcode.tags.contains(trimmed) {
            withAccessibleAnimation {
                barcode.tags.append(trimmed)
                barcode.lastModified = .now
            }
        }
        newTagText = ""
        isAddingTag = false
    }

    @ViewBuilder
    var descriptorDataSection: some View {
        if showAdvancedData, let rows = descriptorRows() ?? generatorOptionsRows() {
            advancedDataCard(
                title: descriptorRows() != nil
                    ? String(localized: "Descriptor Data", comment: "Detail: descriptor data section title")
                    : String(localized: "Generator Options", comment: "Detail: generator options section title"),
                rows: rows
            )
        }
    }

    func advancedDataCard(title: String, rows: [DescriptorRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(
                    Array(rows.enumerated()),
                    id: \.offset
                ) { index, row in
                    HStack {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.value)
                            .monospaced()
                    }
                    .font(.subheadline)
                    .padding(.vertical, 6)

                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(12)
            .background(
                .fill.quinary,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 80)
    }

    func captureCurrentLocation() {
        isCapturingLocation = true
        locationError = nil
        locationManager.lastLocation = nil
        locationManager.requestPermission()
        locationManager.requestLocation()

        Task {
            try? await Task.sleep(for: .seconds(15))
            if isCapturingLocation {
                isCapturingLocation = false
                locationError = String(
                    localized: "Could not determine location. Check that Location Services are enabled in Settings.",
                    comment: "Detail: location capture timeout error"
                )
            }
        }
    }
}
