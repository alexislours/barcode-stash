import CoreLocation
import MapKit

enum ReverseGeocoder {
    private struct CacheEntry {
        let address: String?
        let timestamp: Date
    }

    private static var cache: [String: CacheEntry] = [:]

    private static func cacheKey(latitude: Double, longitude: Double) -> String {
        let lat = (latitude * 1000).rounded() / 1000
        let lon = (longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }

    static func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let key = cacheKey(latitude: latitude, longitude: longitude)

        if let entry = cache[key] {
            // Successful cache hit - return immediately
            if entry.address != nil {
                return entry.address
            }
            // Failed geocode - respect 5-minute cooldown
            if Date.now.timeIntervalSince(entry.timestamp) < 300 {
                return nil
            }
        }

        let result = await Self.fetchAddress(latitude: latitude, longitude: longitude)
        cache[key] = CacheEntry(address: result, timestamp: .now)
        return result
    }

    @concurrent
    private static func fetchAddress(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let mapItem = try? await request.mapItems.first,
              let address = mapItem.address
        else { return nil }
        return address.shortAddress
    }

    static func clearCache() {
        cache.removeAll()
    }
}
