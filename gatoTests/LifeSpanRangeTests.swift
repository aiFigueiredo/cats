import XCTest
@testable import gato

final class LifeSpanRangeTests: XCTestCase {
    func testParsesRangeString() {
        let range = LifeSpanRange(rawValue: "10 - 14")

        XCTAssertEqual(range?.min, 10)
        XCTAssertEqual(range?.max, 14)
    }

    func testParsesSingleValueRange() {
        let range = LifeSpanRange(rawValue: "12")

        XCTAssertEqual(range?.min, 12)
        XCTAssertEqual(range?.max, 12)
    }

    func testInvalidRangeReturnsNil() {
        XCTAssertNil(LifeSpanRange(rawValue: nil))
        XCTAssertNil(LifeSpanRange(rawValue: ""))
        XCTAssertNil(LifeSpanRange(rawValue: "unknown"))
    }
}
