import CoreLocation
import Foundation

/// One stop *as listed inside a route*. The same physical stop appears once per
/// (route, direction), which is why the map works with `Stop` instead.
struct Station: Decodable, Sendable {
    let sid: Int
    let rid: Int
    let lat: Double
    let lng: Double
    let name: String
    let sequenceNumber: Int
    let directionForward: Bool

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

/// A physical stop, deduplicated across routes by `sid`. In the live data `sid` maps
/// 1:1 to a coordinate (433 unique ids, 433 unique coordinates), so this fold is lossless.
struct Stop: Identifiable, Hashable, Sendable {
    let sid: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let routeIDs: Set<Int>

    var id: Int { sid }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    static func fold(_ routes: [Route]) -> [Stop] {
        var names: [Int: String] = [:]
        var points: [Int: (Double, Double)] = [:]
        var served: [Int: Set<Int>] = [:]

        for route in routes {
            for station in route.stations {
                names[station.sid] = station.name.trimmed
                points[station.sid] = (station.lat, station.lng)
                served[station.sid, default: []].insert(route.rid)
            }
        }

        return points.compactMap { sid, point in
            guard let name = names[sid] else { return nil }
            return Stop(
                sid: sid,
                name: name,
                latitude: point.0,
                longitude: point.1,
                routeIDs: served[sid] ?? []
            )
        }
        .sorted { $0.sid < $1.sid }
    }
}
