import SwiftUI

extension Color {
    /// Parses the `#RRGGBB` strings the API assigns to routes.
    init?(hex: String?) {
        guard var raw = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6 || raw.count == 3, let value = UInt32(raw, radix: 16) else {
            return nil
        }

        let (r, g, b): (Double, Double, Double)
        if raw.count == 3 {
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Black or white, whichever stays readable on top of this colour.
    var contrastingLabel: Color {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return .white
        }
        let luminance = 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]
        return luminance > 0.62 ? .black : .white
    }
}
