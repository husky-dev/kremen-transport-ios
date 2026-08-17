#if DEBUG
import Foundation

/// Launch arguments that open a screen directly, so a running build can be inspected and
/// screenshotted from the command line:
///
///     xcrun simctl launch booted dev.kremen.transport -openPicker
///     xcrun simctl launch booted dev.kremen.transport -openStop 305
///
/// DEBUG-only and inert unless the argument is passed.
enum DebugLaunch {
    static var opensPicker: Bool {
        ProcessInfo.processInfo.arguments.contains("-openPicker")
    }

    static var stopToOpen: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-openStop"),
              index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    static var cameraDistance: Double? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-cameraDistance"),
              index + 1 < arguments.count else { return nil }
        return Double(arguments[index + 1])
    }
}
#endif
