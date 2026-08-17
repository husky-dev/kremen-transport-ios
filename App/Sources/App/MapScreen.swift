import MapKit
import SwiftUI

struct MapScreen: View {
    let api: APIClient
    let transport: TransportStore
    let vehicles: VehicleFeed
    @Bindable var selection: SelectionStore
    let location: LocationProvider

    @Environment(\.scenePhase) private var scenePhase

    @State private var viewport = MapViewportModel()
    @State private var position: MapCameraPosition = .camera(MapGeometry.initialCamera)
    @State private var camera: MapCamera = MapGeometry.initialCamera
    @State private var target: MapTarget?
    @State private var highlightedRouteID: Int?
    @State private var isPickerPresented = false
    @State private var isLocationDeniedAlertPresented = false
    @State private var pendingRecenter = false

    /// The live-position endpoint is 14 KB and the backend refreshes it every 10 s.
    private static let positionsInterval = Duration.seconds(5)
    /// The full roster is 78 KB; it only needs to catch vehicles that newly appeared.
    private static let rosterInterval = Duration.seconds(60)

    var body: some View {
        TransportMapView(
            routes: selectedRoutes,
            stops: visibleStops,
            vehicles: visibleVehicles,
            detail: viewport.detail,
            highlightedRouteID: highlightedRouteID,
            position: $position,
            selection: $target,
            onCameraChange: { context in
                camera = context.camera
                viewport.update(context)
            }
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) { statusChip }
        .overlay(alignment: .trailing) { zoomStepper }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $isPickerPresented) {
            RoutePickerView(routes: transport.sortedRoutes, selection: selection)
        }
        .sheet(item: selectedStop) { stop in
            StationSheet(
                stop: stop,
                routesByID: transport.routesByID,
                selectedRouteIDs: selection.selected,
                api: api
            )
        }
        .sheet(item: selectedVehicle) { vehicle in
            VehicleSheet(
                vehicle: vehicle,
                route: transport.route(vehicle.rid),
                onShowRoute: { focus(on: vehicle.rid) }
            )
        }
        .alert("location.denied.title", isPresented: $isLocationDeniedAlertPresented) {
            Button("location.denied.settings") { openSettings() }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("location.denied.message")
        }
        .task {
            await transport.load()
            selection.reconcile(against: transport.knownRouteIDs)
            if selection.isFirstLaunch, selection.selected.isEmpty {
                isPickerPresented = true
            }
            applyDebugLaunchArguments()
        }
        .task(id: isPolling) {
            guard isPolling else { return }
            let positions = Poller.loop(every: Self.positionsInterval) {
                await vehicles.loadPositions()
            }
            let roster = Poller.loop(every: Self.rosterInterval) {
                await vehicles.loadRoster(force: true)
            }
            defer {
                positions.cancel()
                roster.cancel()
            }
            await positions.value
        }
        .onChange(of: location.fixCount) { _, _ in
            // Honour a locate tap that arrived before the first fix did.
            guard pendingRecenter, location.coordinate != nil else { return }
            pendingRecenter = false
            recenterOnUser()
        }
    }

    // MARK: - Chrome

    private var statusChip: some View {
        FreshnessChip(lastUpdate: vehicles.lastUpdate, isFailing: vehicles.isFailing)
            .padding(.leading, 16)
            .padding(.top, 8)
    }

    private var zoomStepper: some View {
        ZoomStepper(
            onZoomIn: { zoom(by: 0.5) },
            onZoomOut: { zoom(by: 2) }
        )
        .padding(.trailing, 12)
        .offset(y: -40)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            FloatingSurface {
                RoutesPill(count: selection.selected.count) { isPickerPresented = true }
            }

            Spacer(minLength: 0)

            FloatingSurface {
                MapIconButton(
                    systemName: location.isAuthorized ? "location.fill" : "location",
                    labelKey: "map.control.locate",
                    isBusy: location.isAwaitingFirstFix,
                    action: locateTapped
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Camera

    private func zoom(by factor: Double) {
        let distance = (camera.distance * factor)
            .clamped(to: MapGeometry.minimumDistance...MapGeometry.maximumDistance)
        withAnimation(.easeInOut(duration: 0.25)) {
            position = .camera(
                MapCamera(
                    centerCoordinate: camera.centerCoordinate,
                    distance: distance,
                    heading: camera.heading,
                    pitch: camera.pitch
                )
            )
        }
    }

    private func locateTapped() {
        switch location.authorization {
        case .notDetermined:
            pendingRecenter = true
            location.requestAuthorization()
        case .denied, .restricted:
            isLocationDeniedAlertPresented = true
        default:
            location.startUpdating()
            if location.coordinate == nil {
                pendingRecenter = true
            } else {
                recenterOnUser()
            }
        }
    }

    private func recenterOnUser() {
        guard let coordinate = location.coordinate else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            position = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: min(camera.distance, 1_500),
                    heading: 0,
                    pitch: 0
                )
            )
        }
    }

    /// "Show route" from the vehicle sheet: select it, highlight it, frame it.
    private func focus(on rid: Int) {
        guard let route = transport.route(rid), !route.path.isEmpty else { return }
        if !selection.contains(rid) { selection.toggle(rid) }
        highlightedRouteID = rid
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .rect(route.boundingRect.padded(by: 0.15))
        }
    }

    private func applyDebugLaunchArguments() {
        #if DEBUG
        if let distance = DebugLaunch.cameraDistance {
            position = .camera(
                MapCamera(centerCoordinate: MapGeometry.cityCenter, distance: distance)
            )
        }
        if DebugLaunch.opensPicker { isPickerPresented = true }
        if let sid = DebugLaunch.stopToOpen { target = .stop(sid) }
        #endif
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Data

    private var isPolling: Bool { scenePhase == .active }

    private var selectedRoutes: [Route] {
        transport.sortedRoutes.filter { selection.contains($0.rid) }
    }

    private var visibleStops: [Stop] {
        viewport.visibleStops(transport.stops, selectedRouteIDs: selection.selected)
    }

    private var visibleVehicles: [Vehicle] {
        viewport.visibleVehicles(
            vehicles.vehicles(onRoutes: selection.selected, includeOffline: selection.showOffline)
        )
    }

    private var selectedStop: Binding<Stop?> {
        Binding(
            get: {
                guard case let .stop(sid) = target else { return nil }
                return transport.stopsByID[sid]
            },
            set: { if $0 == nil, case .stop = target { target = nil } }
        )
    }

    private var selectedVehicle: Binding<Vehicle?> {
        Binding(
            get: {
                guard case let .vehicle(tid) = target else { return nil }
                return vehicles.vehicles[tid]
            },
            set: { if $0 == nil, case .vehicle = target { target = nil } }
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
