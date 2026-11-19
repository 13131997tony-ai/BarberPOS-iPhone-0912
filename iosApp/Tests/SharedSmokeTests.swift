import XCTest
@testable import BarberPOSiOS

final class SharedSmokeTests: XCTestCase {
    func testAppBundlesAllSixApprovedPresets() throws {
        let presets = try XCTUnwrap(ThemePresets.load())
        XCTAssertEqual(presets.map(\.id), [
            "GRAPHITE_RED", "MIDNIGHT_BLUE", "DEEP_MOSS", "WARM_COPPER", "MIDNIGHT_PLUM", "LIGHT_SAND",
        ])
        XCTAssertEqual(presets.first?.action.argb, 0xFFB9362D)
        XCTAssertEqual(presets.last?.dark, false)
    }

    func testRetiredPersonalSelectionFallsBackToShop() {
        XCTAssertEqual(ThemePresets.resolve(personal: "NIGHT_RED", shop: "LIGHT_SAND").id, "LIGHT_SAND")
        XCTAssertEqual(ThemePresets.resolve(personal: "UNKNOWN", shop: "SOI_CEMENT").id, "GRAPHITE_RED")
    }
}
