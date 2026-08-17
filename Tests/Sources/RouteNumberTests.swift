import XCTest
@testable import KremenTransport

/// Route numbers arrive with both Cyrillic `Т` and Latin `T` prefixes, hyphens and stray spaces.
final class RouteNumberTests: XCTestCase {
    func testStripsTrolleybusPrefix() {
        XCTAssertEqual(RouteNumber.badge("Т 1"), "1")
        XCTAssertEqual(RouteNumber.badge("Т 1+"), "1+")
        XCTAssertEqual(RouteNumber.badge("Т3Б"), "3Б")
        XCTAssertEqual(RouteNumber.badge("T11A+"), "11A+")
        XCTAssertEqual(RouteNumber.badge("T15Б"), "15Б")
    }

    func testNormalisesBusNumbers() {
        XCTAssertEqual(RouteNumber.badge("1"), "1")
        XCTAssertEqual(RouteNumber.badge("3-б"), "3Б")
        XCTAssertEqual(RouteNumber.badge("2-в"), "2В")
        XCTAssertEqual(RouteNumber.badge("10A"), "10A")
        XCTAssertEqual(RouteNumber.badge("117"), "117")
    }

    func testSortsNumerically() {
        let input = ["117", "2-в", "10A", "3-а", "15-б", "Т 1"]
        let sorted = input.sorted { RouteNumber.sortKey($0) < RouteNumber.sortKey($1) }
        XCTAssertEqual(sorted, ["Т 1", "2-в", "3-а", "10A", "15-б", "117"])
    }

    func testSearchToleratesCyrillicLatinMixUp() {
        // Someone typing on a Latin keyboard should still find the Cyrillic route.
        XCTAssertTrue(RouteNumber.matches("Т 1", query: "T1"))
        XCTAssertTrue(RouteNumber.matches("T15Б", query: "15"))
        XCTAssertTrue(RouteNumber.matches("3-б", query: "3Б"))
        XCTAssertFalse(RouteNumber.matches("117", query: "9"))
    }
}

final class RouteEndpointTests: XCTestCase {
    private func route(name: String) throws -> Route {
        let json = Data("""
        [{"rid":1,"name":"\(name)","number":"1","type":"B","active":0,"path":[],"stations":[]}]
        """.utf8)
        return try JSONDecoder.transport.decode([Route].self, from: json)[0]
    }

    func testSplitsOnEnDash() throws {
        let route = try route(name: "Річковий вокзал – Укртатнафта")
        XCTAssertEqual(route.destination(reverse: false), "Укртатнафта")
        XCTAssertEqual(route.destination(reverse: true), "Річковий вокзал")
    }

    func testSplitsOnHyphenAndCollapsesDoubleSpaces() throws {
        let route = try route(name: "вул. Юрія  Кондратюка - Укртатнафта")
        XCTAssertEqual(route.destination(reverse: true), "вул. Юрія Кондратюка")
    }

    func testFallsBackToFullNameWhenUnsplittable() throws {
        let route = try route(name: "Кільцевий")
        XCTAssertEqual(route.destination(reverse: false), "Кільцевий")
    }
}
