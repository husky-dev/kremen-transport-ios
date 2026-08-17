import Foundation

enum Formatters {
    /// Arrival countdown. Under a minute reads as seconds, above it rounds up to whole minutes —
    /// a bus "1 minute away" that shows 0 is worse than one that shows 1.
    static func eta(seconds: Int) -> String {
        if seconds <= 5 { return String(localized: "eta.now") }
        if seconds < 60 { return String(format: String(localized: "eta.seconds"), seconds) }
        let minutes = Int((Double(seconds) / 60).rounded(.up))
        return String(format: String(localized: "eta.minutes"), minutes)
    }

    static func distance(metres: Int) -> String {
        if metres < 1000 { return String(format: String(localized: "unit.meters"), metres) }
        let km = (Double(metres) / 1000).formatted(.number.precision(.fractionLength(1)))
        return String(format: String(localized: "unit.km"), km)
    }

    static func speed(kmh: Int) -> String {
        String(format: String(localized: "unit.speed"), kmh)
    }

    /// "щойно" / "12 с тому" / "3 хв тому" — deliberately coarse, it only needs to convey freshness.
    static func freshness(since date: Date?, now: Date = Date()) -> String {
        guard let date else { return String(localized: "map.status.offline") }
        let elapsed = Int(now.timeIntervalSince(date))
        if elapsed < 5 { return String(localized: "map.status.justNow") }
        if elapsed < 60 { return String(format: String(localized: "map.status.secondsAgo"), elapsed) }
        return String(format: String(localized: "map.status.minutesAgo"), elapsed / 60)
    }
}
