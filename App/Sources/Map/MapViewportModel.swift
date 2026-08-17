import MapKit
import SwiftUI
import Observation

/// Decides what is actually handed to the map each frame. Selecting every route would mean
/// 38 polylines, 433 stops and ~200 vehicles; culling to the visible rect keeps the live
/// annotation count inside what SwiftUI `Map` renders smoothly.
@MainActor
@Observable
final class MapViewportModel {
    private(set) var detail: MapDetail = .routes
    private(set) var visibleRect: MKMapRect = .world
    private(set) var cameraDistance: CLLocationDistance = MapGeometry.defaultDistance
    private(set) var centerCoordinate: CLLocationCoordinate2D = MapGeometry.cityCenter

    /// A hard ceiling — beyond this the map is unreadable anyway, so drawing more is waste.
    private static let vehicleLimit = 150
    private static let stopLimit = 120

    func update(_ context: MapCameraUpdateContext) {
        cameraDistance = context.camera.distance
        centerCoordinate = context.camera.centerCoordinate
        visibleRect = context.rect.padded(by: 0.25)
        detail = MapDetail.from(distance: context.camera.distance, previous: detail)
    }

    func visibleStops(_ stops: [Stop], selectedRouteIDs: Set<Int>) -> [Stop] {
        guard detail.showsStops, !selectedRouteIDs.isEmpty else { return [] }
        let rect = visibleRect
        return stops
            .lazy
            .filter { !$0.routeIDs.isDisjoint(with: selectedRouteIDs) }
            .filter { rect.contains(MKMapPoint($0.coordinate)) }
            .prefix(Self.stopLimit)
            .map { $0 }
    }

    func visibleVehicles(_ vehicles: [Vehicle]) -> [Vehicle] {
        let rect = visibleRect
        let inside = vehicles.filter { rect.contains(MKMapPoint($0.coordinate)) }
        guard inside.count > Self.vehicleLimit else { return inside }
        // Over budget: keep the ones closest to where the user is looking.
        let center = MKMapPoint(centerCoordinate)
        return inside
            .sorted { MKMapPoint($0.coordinate).distance(to: center) < MKMapPoint($1.coordinate).distance(to: center) }
            .prefix(Self.vehicleLimit)
            .map { $0 }
    }
}
