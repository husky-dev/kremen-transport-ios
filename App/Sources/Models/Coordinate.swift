import CoreLocation
import Foundation

/// A WGS84 point as the API delivers it: a bare two-element `[lat, lng]` array.
struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var cl: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

extension Coordinate: Decodable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let lat = try container.decode(Double.self)
        let lng = try container.decode(Double.self)
        guard (-90...90).contains(lat), (-180...180).contains(lng) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "coordinate out of range: \(lat), \(lng)"
            )
        }
        latitude = lat
        longitude = lng
    }
}

extension Coordinate {
    /// Metres between two points, good enough for path simplification at city scale.
    func distance(to other: Coordinate) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
