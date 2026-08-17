import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct Route: Decodable, Identifiable, Sendable {
    let rid: Int
    let name: String
    let number: String
    let type: TransitKind
    /// Number of vehicles the backend currently counts on this route.
    let active: Int
    let color: String?
    let path: [Coordinate]
    let stations: [Station]

    var id: Int { rid }

    private enum CodingKeys: String, CodingKey {
        case rid, name, number, type, active, color, path, stations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rid = try c.decode(Int.self, forKey: .rid)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        number = (try? c.decode(String.self, forKey: .number)) ?? ""
        type = (try? c.decode(TransitKind.self, forKey: .type)) ?? .bus
        active = (try? c.decode(Int.self, forKey: .active)) ?? 0
        color = try? c.decode(String.self, forKey: .color)
        // A single malformed pair must not sink the whole 565 KB payload.
        path = (try? c.decode([FailableCoordinate].self, forKey: .path))?.compactMap(\.value) ?? []
        stations = (try? c.decode([Station].self, forKey: .stations)) ?? []
    }
}

extension Route {
    var badge: String { RouteNumber.badge(number) }

    var tint: Color { Color(hex: color) ?? .accentColor }

    /// `"Річковий вокзал – Укртатнафта"` split into its two endpoints. The upstream data
    /// mixes en-dashes, hyphens and stray double spaces.
    var endpoints: (from: String, to: String)? {
        let separators: [String] = [" – ", " — ", " - ", "–", "—"]
        for separator in separators {
            let parts = name.components(separatedBy: separator)
            if parts.count >= 2 {
                let from = parts[0].trimmed
                let to = parts.dropFirst().joined(separator: separator).trimmed
                if !from.isEmpty, !to.isEmpty { return (from, to) }
            }
        }
        return nil
    }

    /// Destination shown for an arrival, given the direction the vehicle is travelling.
    func destination(reverse: Bool) -> String {
        guard let endpoints else { return name.trimmed }
        return reverse ? endpoints.from : endpoints.to
    }

    var boundingRect: MKMapRect {
        path.reduce(MKMapRect.null) { rect, point in
            let mapPoint = MKMapPoint(point.cl)
            return rect.union(MKMapRect(x: mapPoint.x, y: mapPoint.y, width: 0, height: 0))
        }
    }
}

/// Wrapper so `[[Double]]` decoding can skip bad entries instead of throwing.
private struct FailableCoordinate: Decodable {
    let value: Coordinate?

    init(from decoder: Decoder) throws {
        value = try? Coordinate(from: decoder)
    }
}

extension String {
    var trimmed: String {
        // Upstream names contain doubled spaces; collapse them while trimming.
        split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }
}
