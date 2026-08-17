#if DEBUG
import CoreLocation
import Foundation

/// Launch arguments that open a screen directly, so a running build can be inspected and
/// screenshotted from the command line:
///
///     xcrun simctl launch booted dev.kremen.transport -openPicker
///     xcrun simctl launch booted dev.kremen.transport -openStop 305
///     xcrun simctl launch booted dev.kremen.transport -openSettings
///
/// `-fixtures` and `-selectRoutes` additionally pin *what* is on screen, so App Store captures
/// of the same screen in two languages come out identical (see `Scripts/screenshots.sh`).
///
/// DEBUG-only and inert unless the argument is passed.
enum DebugLaunch {
    static var opensPicker: Bool {
        ProcessInfo.processInfo.arguments.contains("-openPicker")
    }

    /// Serve captured payloads instead of the network, so a run is reproducible.
    static var usesFixtures: Bool {
        ProcessInfo.processInfo.arguments.contains("-fixtures")
    }

    static var opensSettings: Bool {
        ProcessInfo.processInfo.arguments.contains("-openSettings")
    }

    static var stopToOpen: Int? {
        value(for: "-openStop").flatMap(Int.init)
    }

    static var cameraDistance: Double? {
        value(for: "-cameraDistance").flatMap(Double.init)
    }

    /// `-cameraCenter 49.1014,33.4240` — otherwise the camera frames `MapGeometry.cityCenter`.
    static var cameraCenter: CLLocationCoordinate2D? {
        guard let raw = value(for: "-cameraCenter") else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }
        return CLLocationCoordinate2D(latitude: parts[0], longitude: parts[1])
    }

    /// `-selectRoutes 2,7,14` — replaces whatever the picker last persisted.
    static var routesToSelect: Set<Int>? {
        guard let raw = value(for: "-selectRoutes") else { return nil }
        let ids = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return ids.isEmpty ? nil : Set(ids)
    }

    /// `-stopDetent medium|large` — the station sheet otherwise opens at its smallest detent.
    static var stopDetent: String? {
        value(for: "-stopDetent")
    }

    /// The values are positional (`-flag value`), not `NSUserDefaults`-style pairs.
    private static func value(for flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
#endif
