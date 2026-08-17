import SwiftUI

struct SettingsSheet: View {
    @Bindable var settings: SettingsStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("settings.appearance.section") {
                    Picker("settings.appearance.section", selection: $settings.appearance) {
                        ForEach(AppearancePreference.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

                Section {
                    // iOS owns the per-app language; there is no supported way to switch it from
                    // inside a running app, so the row reports the current one and hands over.
                    Button {
                        SystemSettings.openAppSettings()
                    } label: {
                        HStack {
                            Text("settings.language.row")
                                .foregroundStyle(.primary)
                            Spacer(minLength: 12)
                            Text(currentLanguageName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    // Without this the whole row picks up the button tint and reads as a link.
                    .buttonStyle(.plain)
                } header: {
                    Text("settings.language.section")
                } footer: {
                    Text("settings.language.footer")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    /// The localization the bundle actually resolved to — not the device language, which may be
    /// a third language that falls back to Ukrainian.
    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "uk"
        let name = Locale.current.localizedString(forLanguageCode: code) ?? code
        return name.localizedCapitalized
    }
}
