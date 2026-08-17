import Foundation
import Observation
import OSLog

/// Live vehicle positions. `transport/buses` supplies the metadata (name, route, offline)
/// and `transport/buses/locations` — 14 KB versus 78 KB — supplies the movement.
@MainActor
@Observable
final class VehicleFeed {
    private(set) var vehicles: [String: Vehicle] = [:]
    private(set) var lastUpdate: Date?
    private(set) var isFailing = false

    private let api: APIClient
    private let log = Logger(subsystem: "dev.kremen.transport", category: "vehicles")

    private var lastRosterFetch: Date = .distantPast
    /// The locations endpoint only *moves* known vehicles; one that appears mid-session shows
    /// up as an unknown tid, and only a full roster fetch can name it.
    private static let rosterCooldown: TimeInterval = 30

    init(api: APIClient) {
        self.api = api
    }

    func vehicles(onRoutes rids: Set<Int>, includeOffline: Bool) -> [Vehicle] {
        vehicles.values.filter { vehicle in
            rids.contains(vehicle.rid) && (includeOffline || !vehicle.offline)
        }
    }

    func loadRoster(force: Bool = false) async {
        guard force || Date().timeIntervalSince(lastRosterFetch) > Self.rosterCooldown else { return }
        do {
            let list = try await api.fetch(.buses, as: [Vehicle].self)
            lastRosterFetch = Date()
            var merged = Dictionary(list.map { ($0.tid, $0) }, uniquingKeysWith: { _, last in last })
            // The roster's own coordinates can lag the last positions tick, so keep ours.
            for (tid, existing) in vehicles where merged[tid] != nil {
                merged[tid]?.apply(
                    VehicleFix(existing.lat, existing.lng, existing.direction, existing.speed)
                )
            }
            vehicles = merged
            lastUpdate = Date()
            isFailing = false
        } catch {
            log.error("roster fetch failed: \(error.localizedDescription, privacy: .public)")
            isFailing = true
        }
    }

    func loadPositions() async {
        do {
            let raw = try await api.fetch(.locations, as: [String: [Double]].self)
            let fixes = VehicleFixes.parse(raw)
            var sawUnknown = false
            for (tid, fix) in fixes {
                if vehicles[tid] != nil {
                    vehicles[tid]?.apply(fix)
                } else {
                    sawUnknown = true
                }
            }
            lastUpdate = Date()
            isFailing = false
            if sawUnknown { await loadRoster() }
        } catch {
            log.error("positions fetch failed: \(error.localizedDescription, privacy: .public)")
            isFailing = true
        }
    }
}
