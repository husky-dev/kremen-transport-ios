import Foundation

/// An arrival forecast for one vehicle at one stop.
struct Prediction: Decodable, Identifiable, Sendable {
    let rid: Int
    let sid: Int
    let tid: String
    /// Seconds until arrival.
    let prediction: Int
    /// Metres away.
    let distance: Int
    /// Which way the vehicle is running. The stop itself carries no reliable direction
    /// (the same `sid` is listed both ways), so this flag is what splits the sheet.
    let reverse: Bool
    let avgSpeed: Int
    let speed: Int
    let mainPrediction: Bool

    var id: String { "\(tid)-\(rid)-\(reverse)" }
    var eta: Date { Date().addingTimeInterval(TimeInterval(prediction)) }
}
