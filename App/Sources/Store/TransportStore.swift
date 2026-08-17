import Foundation
import Observation
import OSLog

/// Slow-moving reference data: routes, their paths and the deduplicated stops.
/// Kept apart from `VehicleFeed` so a 3-second position tick never invalidates the
/// polyline layer or the route picker.
@MainActor
@Observable
final class TransportStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var routesByID: [Int: Route] = [:]
    private(set) var sortedRoutes: [Route] = []
    private(set) var stopsByID: [Int: Stop] = [:]
    private(set) var stops: [Stop] = []
    private(set) var state: LoadState = .idle

    private let api: APIClient
    private let cache: RouteCache
    private let log = Logger(subsystem: "dev.kremen.transport", category: "routes")

    /// Refetch routes at most this often; the backend only rebuilds them hourly.
    private static let maxCacheAge: TimeInterval = 60 * 60

    init(api: APIClient, cache: RouteCache = RouteCache()) {
        self.api = api
        self.cache = cache
    }

    func route(_ rid: Int) -> Route? { routesByID[rid] }

    var knownRouteIDs: Set<Int> { Set(routesByID.keys) }

    /// Cache first so the map paints immediately, then refresh over the network.
    func load() async {
        if routesByID.isEmpty { state = .loading }

        let cached = await cache.load()
        if let cached, let routes = try? await api.decode(cached.payload.data, as: [Route].self) {
            apply(routes)
            if cached.age < Self.maxCacheAge {
                log.info("routes served from cache, age \(Int(cached.age))s")
                return
            }
        }

        await refresh(cached: cached?.payload)
    }

    func refresh(cached: CachedPayload? = nil) async {
        do {
            guard let payload = try await api.fetchRoutesIfChanged(cached: cached) else {
                await cache.touch()
                state = .loaded
                return
            }
            let routes = try await api.decode(payload.data, as: [Route].self)
            apply(routes)
            await cache.store(payload)
        } catch {
            log.error("routes refresh failed: \(error.localizedDescription, privacy: .public)")
            if routesByID.isEmpty {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func apply(_ routes: [Route]) {
        // `uniqueKeysWithValues` would trap if the backend ever repeated a rid.
        routesByID = Dictionary(routes.map { ($0.rid, $0) }, uniquingKeysWith: { _, last in last })
        sortedRoutes = routes.sorted {
            let left = RouteNumber.sortKey($0.number)
            let right = RouteNumber.sortKey($1.number)
            return left == right ? $0.rid < $1.rid : left < right
        }
        let folded = Stop.fold(routes)
        stops = folded
        stopsByID = Dictionary(folded.map { ($0.sid, $0) }, uniquingKeysWith: { _, last in last })
        state = .loaded
    }
}

private func < (lhs: (Int, String), rhs: (Int, String)) -> Bool {
    lhs.0 != rhs.0 ? lhs.0 < rhs.0 : lhs.1 < rhs.1
}
