import SwiftUI

@main
struct KremenTransportApp: App {
    @State private var api = APIClient()
    @State private var transport: TransportStore
    @State private var vehicles: VehicleFeed
    @State private var selection = SelectionStore()
    @State private var settings = SettingsStore()
    @State private var location = LocationProvider()

    init() {
        let client = APIClient()
        _api = State(wrappedValue: client)
        _transport = State(wrappedValue: TransportStore(api: client))
        _vehicles = State(wrappedValue: VehicleFeed(api: client))
    }

    var body: some Scene {
        WindowGroup {
            MapScreen(
                api: api,
                transport: transport,
                vehicles: vehicles,
                selection: selection,
                settings: settings,
                location: location
            )
            // Applied at the window root so sheets and alerts inherit the choice too.
            .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
