import SwiftUI

enum SystemSettings {
    /// Opens this app's page in iOS Settings — where both the location permission and the
    /// per-app language live.
    @MainActor
    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
