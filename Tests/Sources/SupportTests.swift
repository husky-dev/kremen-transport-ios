import SwiftUI
import XCTest
@testable import KremenTransport

final class PolylineSimplifierTests: XCTestCase {
    func testKeepsEndpoints() {
        let points = (0..<50).map {
            Coordinate(latitude: 49.0 + Double($0) * 0.001, longitude: 33.0)
        }
        let simplified = PolylineSimplifier.simplify(points, tolerance: 60)

        XCTAssertEqual(simplified.first, points.first)
        XCTAssertEqual(simplified.last, points.last)
    }

    func testCollapsesAStraightLine() {
        let points = (0..<200).map {
            Coordinate(latitude: 49.0 + Double($0) * 0.0005, longitude: 33.0)
        }
        let simplified = PolylineSimplifier.simplify(points, tolerance: 60)
        XCTAssertEqual(simplified.count, 2, "collinear points carry no shape")
    }

    func testPreservesCorners() {
        var points = (0..<50).map {
            Coordinate(latitude: 49.0, longitude: 33.0 + Double($0) * 0.001)
        }
        points += (1..<50).map {
            Coordinate(latitude: 49.0 + Double($0) * 0.001, longitude: 33.049)
        }
        let simplified = PolylineSimplifier.simplify(points, tolerance: 30)

        XCTAssertGreaterThanOrEqual(simplified.count, 3, "the corner must survive")
        XCTAssertLessThan(simplified.count, points.count)
    }
}

final class SelectionStoreTests: XCTestCase {
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        UserDefaults(suiteName: name)!
    }

    @MainActor
    func testSeedsDefaultRoutesOnFirstLaunch() {
        let store = SelectionStore(defaults: makeDefaults())
        XCTAssertEqual(store.selected, SelectionStore.defaultRouteIDs)
        XCTAssertTrue(store.isFirstLaunch)
    }

    @MainActor
    func testPersistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = SelectionStore(defaults: defaults)
        first.replace(with: [1, 2, 3])

        let second = SelectionStore(defaults: defaults)
        XCTAssertEqual(second.selected, [1, 2, 3])
        XCTAssertFalse(second.isFirstLaunch)
    }

    @MainActor
    func testRemembersAnEmptySelection() {
        let defaults = makeDefaults()
        SelectionStore(defaults: defaults).clear()

        // An explicit "show nothing" must not be re-seeded with the defaults.
        let reloaded = SelectionStore(defaults: defaults)
        XCTAssertTrue(reloaded.selected.isEmpty)
        XCTAssertFalse(reloaded.isFirstLaunch)
    }

    @MainActor
    func testReconcileDropsUnknownRoutes() {
        let store = SelectionStore(defaults: makeDefaults())
        store.replace(with: [1, 2, 999])
        store.reconcile(against: [1, 2, 3])
        XCTAssertEqual(store.selected, [1, 2])
    }

    @MainActor
    func testReconcileIgnoresAnEmptyRouteSet() {
        let store = SelectionStore(defaults: makeDefaults())
        store.replace(with: [1, 2])
        store.reconcile(against: [])
        XCTAssertEqual(store.selected, [1, 2], "routes not loaded yet must not wipe the selection")
    }
}

final class FormattersTests: XCTestCase {
    func testEtaRoundsMinutesUp() {
        XCTAssertEqual(Formatters.eta(seconds: 61).filter(\.isNumber), "2")
        XCTAssertEqual(Formatters.eta(seconds: 120).filter(\.isNumber), "2")
        XCTAssertEqual(Formatters.eta(seconds: 45).filter(\.isNumber), "45")
    }

    func testColourParsing() {
        XCTAssertNotNil(Color(hex: "#6B7A89"))
        XCTAssertNotNil(Color(hex: "6B7A89"))
        XCTAssertNil(Color(hex: "not-a-colour"))
        XCTAssertNil(Color(hex: nil))
    }
}
