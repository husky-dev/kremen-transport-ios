import Foundation
import Observation

/// Arrivals for one stop. Created and destroyed with the sheet, so its poll can never
/// outlive the UI that asked for it.
@MainActor
@Observable
final class PredictionFeed {
    enum State: Equatable {
        case loading
        case loaded
        case failed
    }

    private(set) var predictions: [Prediction] = []
    private(set) var state: State = .loading
    private(set) var lastUpdate: Date?

    private let api: APIClient
    private let sid: Int

    init(api: APIClient, sid: Int) {
        self.api = api
        self.sid = sid
    }

    func reload() async {
        do {
            let items = try await api.fetch(.prediction(sid: sid), as: [Prediction].self)
            predictions = items.sorted { $0.prediction < $1.prediction }
            lastUpdate = Date()
            state = .loaded
        } catch {
            // A silent refresh failure must not blank out arrivals already on screen.
            if predictions.isEmpty { state = .failed }
        }
    }
}
