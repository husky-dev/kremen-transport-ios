import Foundation

enum APIError: LocalizedError, Sendable {
    case server(code: String, message: String?)
    case http(status: Int)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case let .server(code, message): message ?? code
        case let .http(status): "HTTP \(status)"
        case let .decoding(detail): detail
        case let .transport(detail): detail
        }
    }

    /// The API answers non-2xx with `{ "code": "...", "message": "..." }`.
    struct Body: Decodable {
        let code: String
        let message: String?
    }
}
