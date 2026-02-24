import Testing
@testable import gato

@Suite("LifeSpanRange")
struct LifeSpanRangeTests {
    @Test("parses range string")
    func parsesRangeString() {
        let range = LifeSpanRange(rawValue: "10 - 14")

        #expect(range?.min == 10)
        #expect(range?.max == 14)
    }

    @Test("parses single value range")
    func parsesSingleValueRange() {
        let range = LifeSpanRange(rawValue: "12")

        #expect(range?.min == 12)
        #expect(range?.max == 12)
    }

    @Test("invalid range returns nil")
    func invalidRangeReturnsNil() {
        #expect(LifeSpanRange(rawValue: nil) == nil)
        #expect(LifeSpanRange(rawValue: "") == nil)
        #expect(LifeSpanRange(rawValue: "unknown") == nil)
    }
}
