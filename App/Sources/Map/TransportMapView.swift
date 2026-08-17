import MapKit
import SwiftUI

/// The only file that knows how the map is drawn. Everything above it deals in
/// selections and camera commands, so swapping in an `MKMapView` later touches nothing else.
struct TransportMapView: View {
    let routes: [Route]
    let stops: [Stop]
    let vehicles: [Vehicle]
    let detail: MapDetail
    let highlightedRouteID: Int?

    @Binding var position: MapCameraPosition
    @Binding var selection: MapTarget?

    let onCameraChange: (MapCameraUpdateContext) -> Void

    var body: some View {
        Map(position: $position, bounds: cameraBounds, selection: $selection) {
            UserAnnotation()

            ForEach(routes) { route in
                MapPolyline(coordinates: RoutePathCache.shared.path(for: route, detail: detail))
                    .stroke(
                        route.tint.opacity(opacity(for: route.rid)),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }

            if detail.showsStops {
                ForEach(stops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                        StopMarker(isSelected: selection == MapTarget.stop(stop.sid))
                    }
                    .annotationTitles(.hidden)
                    .tag(MapTarget.stop(stop.sid))
                }
            }

            ForEach(vehicles) { vehicle in
                Annotation(vehicle.name, coordinate: vehicle.coordinate, anchor: .center) {
                    VehicleMarker(
                        vehicle: vehicle,
                        route: routesByID[vehicle.rid],
                        showsLabel: detail.showsVehicleLabels,
                        isSelected: selection == MapTarget.vehicle(vehicle.tid)
                    )
                }
                .annotationTitles(.hidden)
                .tag(MapTarget.vehicle(vehicle.tid))
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {} // We ship our own, positioned for one-handed reach.
        .onMapCameraChange(frequency: .onEnd, onCameraChange)
    }

    private var routesByID: [Int: Route] {
        Dictionary(routes.map { ($0.rid, $0) }, uniquingKeysWith: { _, last in last })
    }

    private var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            centerCoordinateBounds: MapGeometry.cityRegion,
            minimumDistance: MapGeometry.minimumDistance,
            maximumDistance: MapGeometry.maximumDistance
        )
    }

    /// Highlighting one route dims the rest rather than hiding them, so you keep the context
    /// of where the other lines run.
    private func opacity(for rid: Int) -> Double {
        guard let highlightedRouteID else { return 0.55 }
        return rid == highlightedRouteID ? 0.95 : 0.15
    }
}
