import ClaudeUsageBarCore
import Foundation
import Testing

/// `resets_at` arrives with six fractional digits, or none, and a `+00:00` offset.
/// `ISO8601DateFormatter`'s `.withFractionalSeconds` is documented for milliseconds only,
/// so the parser is Core's own and every shape it must accept is pinned here.
@Suite("UsageTimestamp")
struct UsageTimestampTests {
    /// 2026-09-30T12:00:00Z, worked out by hand: 20,726 days after 1970-01-01, plus 12 h.
    static let noonUTC = Date(timeIntervalSince1970: 1_790_769_600)

    @Test(arguments: [
        ("2026-09-30T12:00:00+00:00", 0.0),
        ("2026-09-30T12:00:00Z", 0.0),
        ("2026-09-30T12:00:00.633985+00:00", 0.633985),
        ("2026-09-30T12:00:00.5+00:00", 0.5),
        ("2026-09-30T12:00:00.123+0000", 0.123),
        ("2026-09-30T21:00:00+09:00", 0.0),
        ("2026-09-30T07:30:00-04:30", 0.0),
    ])
    func `parses every shape the endpoint sends`(text: String, fraction: Double) throws {
        let date = try #require(UsageTimestamp.date(from: text))
        let expected = Self.noonUTC.addingTimeInterval(fraction)
        #expect(abs(date.timeIntervalSince(expected)) < 0.000001, "\(text) → \(date)")
    }

    @Test(arguments: [
        "",
        "not a date",
        "2026-09-30",
        "2026-09-30 12:00:00+00:00",
        "2026-13-30T12:00:00+00:00",
        "2026-02-30T12:00:00+00:00",
        "2026-09-30T24:00:00+00:00",
        "2026-09-30T12:00:00.+00:00",
        "2026-09-30T12:00:00+0:00",
        "2026-09-30T12:00:00+00:00trailing",
    ])
    func `rejects anything that is not an RFC 3339 timestamp`(text: String) {
        #expect(UsageTimestamp.date(from: text) == nil)
    }
}
