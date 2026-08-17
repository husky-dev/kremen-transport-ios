import Observation
import SwiftUI

/// Light / dark / follow-the-system. `system` is the default because every colour in the app is
/// already semantic — the override exists for people whose device-wide choice isn't what they
/// want on a map.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil` hands the decision back to the system, which is what `preferredColorScheme` expects.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.system"
        case .light: "settings.appearance.light"
        case .dark: "settings.appearance.dark"
        }
    }
}

/// App-level preferences. Persisted immediately on change, like `SelectionStore` — the settings
/// sheet has no "apply" step, so what you tap is what survives a relaunch.
@MainActor
@Observable
final class SettingsStore {
    private static let appearanceKey = "settings.appearance.v1"

    private let defaults: UserDefaults

    var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.appearanceKey)
        appearance = stored.flatMap(AppearancePreference.init(rawValue:)) ?? .system
    }
}
