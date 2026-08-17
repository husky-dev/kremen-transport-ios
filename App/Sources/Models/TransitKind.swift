import Foundation

/// The API's `type` field: `"B"` bus, `"T"` trolleybus.
enum TransitKind: String, Codable, CaseIterable, Sendable {
    case bus = "B"
    case trolleybus = "T"

    /// Unknown values decode as a bus rather than failing the whole payload.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TransitKind(rawValue: raw) ?? .bus
    }

    var symbolName: String {
        switch self {
        case .bus: "bus.fill"
        case .trolleybus: "cablecar.fill"
        }
    }

    var sectionTitleKey: String {
        switch self {
        case .bus: "routes.section.bus"
        case .trolleybus: "routes.section.trolley"
        }
    }
}
