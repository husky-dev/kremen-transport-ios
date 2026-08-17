import CoreLocation
import Foundation
import MapKit
import SwiftUI

enum MapGeometry {
    /// Kremenchuk, matching the centre the web and 1.4 apps both open on.
    static let cityCenter = CLLocationCoordinate2D(
        latitude: 49.07041247214882, longitude: 33.42281959697266
    )

    /// The bounding box of the live route data, padded a little.
    static let cityRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 49.0884, longitude: 33.4779),
        span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.28)
    )

    /// Camera height on launch — roughly the web app's Google zoom 14.
    static let defaultDistance: CLLocationDistance = 8_000
    static let minimumDistance: CLLocationDistance = 250
    static let maximumDistance: CLLocationDistance = 60_000

    static var initialCamera: MapCamera {
        MapCamera(centerCoordinate: cityCenter, distance: defaultDistance, heading: 0, pitch: 0)
    }
}

/// How much detail the map is showing, derived from camera height. Thresholds carry hysteresis
/// so a marker style doesn't strobe when you hover right on a boundary.
enum MapDetail: Comparable {
    case city
    case routes
    case stops

    static func from(distance: CLLocationDistance, previous: MapDetail) -> MapDetail {
        let stopsIn: CLLocationDistance = 3_000
        let stopsOut: CLLocationDistance = 3_450
        let routesIn: CLLocationDistance = 9_000
        let routesOut: CLLocationDistance = 10_350

        if distance < (previous == .stops ? stopsOut : stopsIn) { return .stops }
        if distance < (previous == .city ? routesIn : routesOut) { return .routes }
        return .city
    }

    var showsStops: Bool { self == .stops }
    var showsVehicleLabels: Bool { self != .city }
}

extension MKMapRect {
    /// Grown by a fraction on every side, so annotations just off screen stay mounted
    /// and don't pop in during a pan.
    func padded(by fraction: Double) -> MKMapRect {
        let dx = width * fraction
        let dy = height * fraction
        return insetBy(dx: -dx, dy: -dy)
    }
}
