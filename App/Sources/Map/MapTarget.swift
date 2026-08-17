import Foundation

/// One binding drives both detail sheets. Tagging annotations beats attaching a gesture to
/// each marker view, which is where SwiftUI `Map` annotation cost explodes.
enum MapTarget: Hashable {
    case stop(Int)
    case vehicle(String)
}
