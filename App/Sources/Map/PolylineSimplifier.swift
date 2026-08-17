import CoreLocation
import Foundation
import MapKit

/// Ramer–Douglas–Peucker. Route paths run to 664 points each; at city zoom most of them are
/// sub-pixel, so thinning them before they reach `MapPolyline` costs nothing visually.
enum PolylineSimplifier {
    static func simplify(_ points: [Coordinate], tolerance: Double) -> [Coordinate] {
        guard points.count > 2, tolerance > 0 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        reduce(points, 0, points.count - 1, tolerance, &keep)
        return zip(points, keep).compactMap { $1 ? $0 : nil }
    }

    private static func reduce(
        _ points: [Coordinate], _ first: Int, _ last: Int,
        _ tolerance: Double, _ keep: inout [Bool]
    ) {
        guard last > first + 1 else { return }

        var farthest = first
        var maxDistance = 0.0
        let start = MKMapPoint(points[first].cl)
        let end = MKMapPoint(points[last].cl)

        for index in (first + 1)..<last {
            let distance = perpendicularDistance(MKMapPoint(points[index].cl), start, end)
            if distance > maxDistance {
                maxDistance = distance
                farthest = index
            }
        }

        // MKMapPoint units scale with latitude; convert the tolerance once at this latitude.
        let unitsPerMetre = 1 / MKMetersPerMapPointAtLatitude(points[first].latitude)
        guard maxDistance > tolerance * unitsPerMetre else { return }

        keep[farthest] = true
        reduce(points, first, farthest, tolerance, &keep)
        reduce(points, farthest, last, tolerance, &keep)
    }

    private static func perpendicularDistance(
        _ point: MKMapPoint, _ start: MKMapPoint, _ end: MKMapPoint
    ) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if dx == 0, dy == 0 {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let numerator = abs(dy * point.x - dx * point.y + end.x * start.y - end.y * start.x)
        return numerator / hypot(dx, dy)
    }
}

/// Simplified paths are computed once per route and reused across camera changes.
@MainActor
final class RoutePathCache {
    static let shared = RoutePathCache()

    private var coarse: [Int: [CLLocationCoordinate2D]] = [:]
    private var fine: [Int: [CLLocationCoordinate2D]] = [:]

    func path(for route: Route, detail: MapDetail) -> [CLLocationCoordinate2D] {
        if detail == .city {
            if let cached = coarse[route.rid] { return cached }
            let value = PolylineSimplifier.simplify(route.path, tolerance: 60).map(\.cl)
            coarse[route.rid] = value
            return value
        }
        if let cached = fine[route.rid] { return cached }
        let value = PolylineSimplifier.simplify(route.path, tolerance: 12).map(\.cl)
        fine[route.rid] = value
        return value
    }

    func invalidate() {
        coarse.removeAll()
        fine.removeAll()
    }
}
