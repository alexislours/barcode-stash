import MapKit
import SwiftData
import SwiftUI

enum MapStyleOption: String, CaseIterable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"

    var localizedName: String {
        switch self {
        case .standard: String(localized: "Standard", comment: "Map style option")
        case .satellite: String(localized: "Satellite", comment: "Map style option")
        case .hybrid: String(localized: "Hybrid", comment: "Map style option")
        }
    }

    var style: MapStyle {
        switch self {
        case .standard: .standard(elevation: .flat)
        case .satellite: .imagery(elevation: .flat)
        case .hybrid: .hybrid(elevation: .flat)
        }
    }

    var icon: String {
        switch self {
        case .standard: "map"
        case .satellite: "globe.americas"
        case .hybrid: "square.stack.3d.up"
        }
    }
}

struct MapView: View {
    @Query private var barcodes: [ScannedBarcode]
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBarcode: ScannedBarcode?
    @AppStorage("mapStyle") private var mapStyle: MapStyleOption = .standard

    private var barcodesWithLocation: [ScannedBarcode] {
        barcodes.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if barcodesWithLocation.isEmpty {
                    ContentUnavailableView(
                        "No Locations",
                        systemImage: "map",
                        description: Text("Scanned barcodes with location data will appear here.")
                    )
                } else {
                    Map(position: $position, selection: $selectedBarcode) {
                        UserAnnotation()
                        ForEach(barcodesWithLocation) { barcode in
                            if let latitude = barcode.latitude,
                               let longitude = barcode.longitude {
                                Marker(
                                    barcode.barcodeDescription ?? barcode.rawValue,
                                    coordinate: CLLocationCoordinate2D(
                                        latitude: latitude,
                                        longitude: longitude
                                    )
                                )
                                .tag(barcode)
                            }
                        }
                    }
                    .mapStyle(mapStyle.style)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                        MapPitchToggle()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .onChange(of: barcodesWithLocation.count) {
                        position = .automatic
                    }
                    .onChange(of: mapStyle) {
                        position = .automatic
                    }
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAccessibleAnimation {
                            position = .automatic
                        }
                    } label: {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise")
                    }
                    .disabled(barcodesWithLocation.isEmpty)
                    .accessibilityLabel(String(localized: "Reset map view", comment: "Map: reset view button"))
                    .accessibilityHint(
                        String(
                            localized: "Resets the map to show all barcode locations",
                            comment: "Map: reset view button hint"
                        )
                    )

                    Menu {
                        Picker("Map Style", selection: $mapStyle) {
                            ForEach(MapStyleOption.allCases, id: \.self) { option in
                                Label(option.localizedName, systemImage: option.icon)
                            }
                        }
                    } label: {
                        Image(systemName: mapStyle.icon)
                    }
                    .accessibilityLabel(
                        String(
                            localized: "Map style: \(mapStyle.localizedName)",
                            comment: "Map: map style picker button"
                        )
                    )
                }
            }
            .navigationDestination(item: $selectedBarcode) { barcode in
                BarcodeDetailView(barcode: barcode)
            }
        }
    }
}
