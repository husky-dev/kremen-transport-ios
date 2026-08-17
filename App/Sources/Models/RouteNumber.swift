import Foundation

/// Route numbers arrive unnormalised: `"1"`, `"3-б"`, `"10A"`, `"117"`, `"Т 1+"`, `"T15Б"`.
/// The leading letter is a Cyrillic *or* Latin T marking a trolleybus, so it carries no
/// information once the route's `type` is known — strip it for badges.
enum RouteNumber {
    private static let trolleyPrefixes: Set<Character> = ["Т", "т", "T", "t"]

    /// Compact label for a marker or badge: `"Т 1+"` -> `"1+"`, `"3-б"` -> `"3Б"`.
    static func badge(_ raw: String) -> String {
        var value = Substring(raw.trimmingCharacters(in: .whitespaces))
        while let first = value.first, trolleyPrefixes.contains(first) || first == " " {
            value = value.dropFirst()
        }
        // Fully-alphabetic numbers (never seen in live data, but be safe) keep their prefix.
        if value.isEmpty { value = Substring(raw) }
        return value
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    /// Natural ordering: numeric part first, then any suffix. `2-в` < `3-а` < `10A` < `117`.
    static func sortKey(_ raw: String) -> (Int, String) {
        let badge = badge(raw)
        let digits = badge.prefix { $0.isNumber }
        let suffix = badge.dropFirst(digits.count)
        return (Int(digits) ?? Int.max, String(suffix))
    }

    /// Does this route match a free-text query? Tolerates the Cyrillic/Latin `Т` mix-up
    /// so typing `T1` finds `Т 1`.
    static func matches(_ raw: String, query: String) -> Bool {
        let needle = badge(query)
        guard !needle.isEmpty else { return true }
        return badge(raw).contains(needle)
    }
}
