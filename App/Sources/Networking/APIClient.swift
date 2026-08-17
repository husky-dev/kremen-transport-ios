import Foundation
import OSLog

enum APIEndpoint: Sendable {
    case routes
    case buses
    case locations
    case prediction(sid: Int)

    var path: String {
        switch self {
        case .routes: "transport/routes"
        case .buses: "transport/buses"
        case .locations: "transport/buses/locations"
        case let .prediction(sid): "transport/stations/\(sid)/prediction"
        }
    }

    /// Live positions must never come from a cache.
    var bypassesCache: Bool {
        switch self {
        case .locations, .buses, .prediction: true
        case .routes: false
        }
    }
}

/// Payload plus the validators needed for a conditional refetch.
struct CachedPayload: Sendable {
    let data: Data
    let etag: String?
    let lastModified: String?
}

actor APIClient {
    static let baseURL = URL(string: "https://api.husky-dev.me/")!

    private let session: URLSession
    private let decoder: JSONDecoder
    private let log = Logger(subsystem: "dev.kremen.transport", category: "api")

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
        decoder = JSONDecoder.transport
    }

    func fetch<T: Decodable & Sendable>(_ endpoint: APIEndpoint, as _: T.Type) async throws -> T {
        let (data, _) = try await load(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            log.error("decode \(endpoint.path, privacy: .public) failed: \(error)")
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Fetches routes, honouring `If-None-Match` / `If-Modified-Since`. Returns `nil` on 304.
    func fetchRoutesIfChanged(cached: CachedPayload?) async throws -> CachedPayload? {
        var request = URLRequest(url: APIEndpoint.routes.url)
        if let etag = cached?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let modified = cached?.lastModified {
            request.setValue(modified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await perform(request)
        if response.statusCode == 304 { return nil }
        try validate(response, data: data)
        return CachedPayload(
            data: data,
            etag: response.value(forHTTPHeaderField: "ETag"),
            lastModified: response.value(forHTTPHeaderField: "Last-Modified")
        )
    }

    func decode<T: Decodable & Sendable>(_ data: Data, as _: T.Type) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - Plumbing

    private func load(_ endpoint: APIEndpoint) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: endpoint.url)
        if endpoint.bypassesCache { request.cachePolicy = .reloadIgnoringLocalCacheData }
        let (data, response) = try await perform(request)
        try validate(response, data: data)
        return (data, response)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport("not an HTTP response")
            }
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200...299).contains(response.statusCode) else { return }
        if let body = try? decoder.decode(APIError.Body.self, from: data) {
            throw APIError.server(code: body.code, message: body.message)
        }
        throw APIError.http(status: response.statusCode)
    }
}

private extension APIEndpoint {
    var url: URL { APIClient.baseURL.appendingPathComponent(path) }
}
