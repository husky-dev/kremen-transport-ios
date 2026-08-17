import CoreLocation
import Foundation
import Observation

/// Thin `CLLocationManager` wrapper. Permission is requested lazily — on the first tap of the
/// locate button — so the app never greets a new user with a system alert.
@MainActor
@Observable
final class LocationProvider: NSObject {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var isAwaitingFirstFix = false
    /// `CLLocationCoordinate2D` isn't `Equatable`, so views observe this instead.
    private(set) var fixCount = 0

    private let manager = CLLocationManager()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    func requestAuthorization() {
        isAwaitingFirstFix = true
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorization = status
            if isAuthorized {
                startUpdating()
            } else {
                isAwaitingFirstFix = false
            }
        }
    }

    nonisolated func locationManager(
        _: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        let value = last.coordinate
        Task { @MainActor in
            coordinate = value
            fixCount += 1
            isAwaitingFirstFix = false
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        Task { @MainActor in isAwaitingFirstFix = false }
    }
}
