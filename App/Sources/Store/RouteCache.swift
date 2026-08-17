import Foundation
import OSLog

/// Disk cache for the 565 KB routes payload so a warm launch draws the map without a network
/// round-trip. Stores the raw bytes plus the HTTP validators for a conditional refetch.
actor RouteCache {
    private let log = Logger(subsystem: "dev.kremen.transport", category: "cache")
    private let directory: URL
    private let payloadURL: URL
    private let metaURL: URL

    private struct Meta: Codable {
        var etag: String?
        var lastModified: String?
        var fetchedAt: Date
    }

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KremenTransport", isDirectory: true)
        self.directory = base
        payloadURL = base.appendingPathComponent("routes.v1.json")
        metaURL = base.appendingPathComponent("routes.v1.meta.json")
    }

    func load() -> (payload: CachedPayload, age: TimeInterval)? {
        guard let data = try? Data(contentsOf: payloadURL) else { return nil }
        let meta = (try? Data(contentsOf: metaURL))
            .flatMap { try? JSONDecoder().decode(Meta.self, from: $0) }
        return (
            CachedPayload(data: data, etag: meta?.etag, lastModified: meta?.lastModified),
            Date().timeIntervalSince(meta?.fetchedAt ?? .distantPast)
        )
    }

    func store(_ payload: CachedPayload) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            try payload.data.write(to: payloadURL, options: .atomic)
            let meta = Meta(
                etag: payload.etag, lastModified: payload.lastModified, fetchedAt: Date()
            )
            try JSONEncoder().encode(meta).write(to: metaURL, options: .atomic)
            excludeFromBackup()
        } catch {
            log.error("route cache write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Refreshes only the timestamp — used after a 304, where the payload is still current.
    func touch() {
        guard let data = try? Data(contentsOf: metaURL),
              var meta = try? JSONDecoder().decode(Meta.self, from: data) else { return }
        meta.fetchedAt = Date()
        try? JSONEncoder().encode(meta).write(to: metaURL, options: .atomic)
    }

    private func excludeFromBackup() {
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
