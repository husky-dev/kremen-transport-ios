import CoreLocation
import Foundation

/// A vehicle as returned by `transport/buses`. `tid` is the GPS device id and is stable.
struct Vehicle: Decodable, Identifiable, Sendable {
    let tid: String
    let rid: Int
    let name: String
    let type: TransitKind
    let offline: Bool
    var lat: Double
    var lng: Double
    /// Heading in degrees, 0 = north.
    var direction: Double
    /// km/h. The backend sends `-1` when it doesn't know.
    var speed: Int
    let updatedAt: Date?

    var id: String { tid }
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    var knownSpeed: Int? { speed >= 0 ? speed : nil }

    private enum CodingKeys: String, CodingKey {
        case tid, rid, name, type, offline, lat, lng, direction, speed
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tid = try c.decode(String.self, forKey: .tid)
        rid = (try? c.decode(Int.self, forKey: .rid)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        type = (try? c.decode(TransitKind.self, forKey: .type)) ?? .bus
        offline = (try? c.decode(Bool.self, forKey: .offline)) ?? false
        lat = (try? c.decode(Double.self, forKey: .lat)) ?? 0
        lng = (try? c.decode(Double.self, forKey: .lng)) ?? 0
        direction = (try? c.decode(Double.self, forKey: .direction)) ?? 0
        speed = (try? c.decode(Int.self, forKey: .speed)) ?? -1
        updatedAt = try? c.decode(Date.self, forKey: .updatedAt)
    }

    mutating func apply(_ fix: VehicleFix) {
        lat = fix.latitude
        lng = fix.longitude
        direction = fix.direction
        speed = fix.speed
    }
}

/// One entry of `transport/buses/locations`: `{ tid: [lat, lng, direction, speed] }`.
struct VehicleFix: Sendable {
    let latitude: Double
    let longitude: Double
    let direction: Double
    let speed: Int

    init(_ latitude: Double, _ longitude: Double, _ direction: Double, _ speed: Int) {
        self.latitude = latitude
        self.longitude = longitude
        self.direction = direction
        self.speed = speed
    }

    init?(_ values: [Double]) {
        guard values.count >= 4 else { return nil }
        guard (-90...90).contains(values[0]), (-180...180).contains(values[1]) else { return nil }
        latitude = values[0]
        longitude = values[1]
        direction = values[2]
        speed = Int(values[3])
    }
}

enum VehicleFixes {
    static func parse(_ raw: [String: [Double]]) -> [String: VehicleFix] {
        raw.compactMapValues(VehicleFix.init)
    }
}
