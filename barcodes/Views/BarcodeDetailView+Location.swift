import CoreLocation
import MapKit
import SwiftUI

// MARK: - Location Section

extension BarcodeDetailView {
    @ViewBuilder
    var locationSection: some View {
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
            addLocationButton
        }
    }

    private var addLocationButton: some View {
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
}
