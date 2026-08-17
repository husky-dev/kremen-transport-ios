import XCTest
@testable import KremenTransport

/// Decodes the real payloads captured from the live API, so a shape change upstream
/// fails here rather than on a user's map.
final class DecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: name, withExtension: "json"),
            "missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }

    func testDecodesRoutes() throws {
        let routes = try JSONDecoder.transport.decode([Route].self, from: fixture("routes.sample"))

        XCTAssertEqual(routes.count, 38)
        XCTAssertEqual(routes.filter { $0.type == .bus }.count, 22)
        XCTAssertEqual(routes.filter { $0.type == .trolleybus }.count, 16)
        XCTAssertTrue(routes.allSatisfy { $0.color != nil }, "live data always carries a colour")

        let route = try XCTUnwrap(routes.first { $0.rid == 12 })
        XCTAssertEqual(route.number, "1")
        XCTAssertEqual(route.type, .bus)
        XCTAssertFalse(route.path.isEmpty)

        // `path` is [lat, lng] — a swap would put every route in Africa.
        let first = try XCTUnwrap(route.path.first)
        XCTAssertEqual(first.latitude, 49.06477, accuracy: 0.0001)
        XCTAssertEqual(first.longitude, 33.41921, accuracy: 0.0001)
    }

    func testFoldsStationsIntoUniqueStops() throws {
        let routes = try JSONDecoder.transport.decode([Route].self, from: fixture("routes.sample"))

        let stationEntries = routes.reduce(0) { $0 + $1.stations.count }
        XCTAssertEqual(stationEntries, 1994)

        let stops = Stop.fold(routes)
        XCTAssertEqual(stops.count, 433, "sid maps 1:1 to a coordinate")

        // Every stop knows which routes serve it, and busy ones serve many.
        let market = try XCTUnwrap(stops.first { $0.sid == 305 })
        XCTAssertEqual(market.name, "Центральний ринок")
        XCTAssertGreaterThan(market.routeIDs.count, 1)

        let coordinates = Set(stops.map { "\($0.latitude),\($0.longitude)" })
        XCTAssertEqual(coordinates.count, stops.count)
    }

    func testDecodesVehicles() throws {
        let vehicles = try JSONDecoder.transport.decode([Vehicle].self, from: fixture("buses.sample"))

        XCTAssertEqual(vehicles.count, 319)
        XCTAssertEqual(Set(vehicles.map(\.tid)).count, 319, "tid is unique")

        let vehicle = try XCTUnwrap(vehicles.first { $0.tid == "352093083862630" })
        XCTAssertEqual(vehicle.rid, 1)
        XCTAssertEqual(vehicle.direction, 150)
        XCTAssertEqual(vehicle.speed, 45)
        XCTAssertNotNil(vehicle.updatedAt, "six fractional digits must still parse")
    }

    func testDecodesLocationsAndMerges() throws {
        let raw = try JSONDecoder.transport.decode(
            [String: [Double]].self, from: fixture("locations.sample")
        )
        let fixes = VehicleFixes.parse(raw)
        XCTAssertEqual(fixes.count, 319)

        var vehicles = try JSONDecoder.transport.decode(
            [Vehicle].self, from: fixture("buses.sample")
        )
        let fix = try XCTUnwrap(fixes["352093083862630"])
        vehicles[0].apply(fix)

        XCTAssertEqual(vehicles[0].lat, fix.latitude)
        XCTAssertEqual(vehicles[0].lng, fix.longitude)
    }

    func testRejectsMalformedLocationEntries() {
        XCTAssertNil(VehicleFix([49.0, 33.0]), "short arrays are dropped")
        XCTAssertNil(VehicleFix([999, 33.0, 0, 0]), "out-of-range latitude is dropped")
        XCTAssertNotNil(VehicleFix([49.0, 33.0, 150, 45]))
    }

    func testDecodesPredictions() throws {
        let items = try JSONDecoder.transport.decode(
            [Prediction].self, from: fixture("prediction.sample")
        )
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { $0.sid == 305 })
        // Both directions come back for one sid — which is why the sheet splits on `reverse`.
        XCTAssertTrue(items.allSatisfy { $0.prediction >= 0 })
    }

    func testSkipsMalformedPathPoints() throws {
        let json = Data("""
        [{"rid":1,"name":"A – B","number":"1","type":"B","active":0,"color":"#FF0000",
          "path":[[49.0,33.0],[999,33.0],[49.1,33.1]],"stations":[]}]
        """.utf8)
        let routes = try JSONDecoder.transport.decode([Route].self, from: json)
        XCTAssertEqual(routes[0].path.count, 2, "one bad pair must not sink the payload")
    }
}
