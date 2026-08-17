import Foundation
import Observation

/// Which routes the user wants on the map. Persisted immediately on every change — there is
/// no "cancel" in the picker, so what you tap is what survives a relaunch.
@MainActor
@Observable
final class SelectionStore {
    /// `v2` because the backend renumbered every route; ids saved by the 1.4 app are meaningless.
    private static let key = "selection.routeIDs.v2"
    private static let offlineKey = "selection.showOffline.v1"

    /// Routes «3-б», «15», «17», «15-б» — four busy lines, so the first launch isn't an empty map.
    static let defaultRouteIDs: Set<Int> = [16, 7, 2, 10]

    private let defaults: UserDefaults

    private(set) var selected: Set<Int>
    /// Did the user ever open the picker? Drives the first-run prompt.
    let isFirstLaunch: Bool

    var showOffline: Bool {
        didSet { defaults.set(showOffline, forKey: Self.offlineKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.array(forKey: Self.key) as? [Int] {
            selected = Set(stored)
            isFirstLaunch = false
        } else {
            selected = Self.defaultRouteIDs
            isFirstLaunch = true
        }
        showOffline = defaults.bool(forKey: Self.offlineKey)
    }

    func contains(_ rid: Int) -> Bool { selected.contains(rid) }

    func toggle(_ rid: Int) {
        if selected.contains(rid) { selected.remove(rid) } else { selected.insert(rid) }
        persist()
    }

    func replace(with ids: Set<Int>) {
        selected = ids
        persist()
    }

    func clear() { replace(with: []) }

    /// Drops ids that no longer exist upstream, but only once real routes have loaded.
    func reconcile(against known: Set<Int>) {
        guard !known.isEmpty else { return }
        let filtered = selected.intersection(known)
        guard filtered != selected else { return }
        selected = filtered
        persist()
    }

    private func persist() {
        defaults.set(Array(selected), forKey: Self.key)
    }
}
