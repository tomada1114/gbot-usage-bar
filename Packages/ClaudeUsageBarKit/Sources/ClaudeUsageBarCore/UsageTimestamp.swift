import Foundation

/// Parses the endpoint's `resets_at` timestamps, such as
/// `2026-09-30T12:00:00.633985+00:00`.
///
/// Hand-written rather than `ISO8601DateFormatter` or `Date.ISO8601FormatStyle`: the
/// endpoint sends six fractional digits on some values and none on others, and one
/// formatter configuration does not reliably accept both, so the shape is matched here
/// and pinned by `UsageTimestampTests`.
public enum UsageTimestamp {
    /// The date `text` names, or `nil` when it is not an RFC 3339 date-time: a `T`
    /// separator, optional fractional seconds of any length, and `Z` or a `±hh:mm`
    /// (or `±hhmm`) offset.
    public static func date(from text: String) -> Date? {
        let pattern = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|([+-])(\d{2}):?(\d{2}))$/
        guard let match = text.wholeMatch(of: pattern) else {
            return nil
        }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? utc.timeZone
        let local = DateComponents(
            year: Int(match.1),
            month: Int(match.2),
            day: Int(match.3),
            hour: Int(match.4),
            minute: Int(match.5),
            second: Int(match.6),
        )
        // The offset is subtracted as calendar components, which carry across an hour,
        // a day, or a month boundary the way the offset's own arithmetic would.
        let direction = match.9 == "-" ? 1 : -1
        let toUTC = DateComponents(
            hour: match.10.flatMap { Int($0) }.map { $0 * direction },
            minute: match.11.flatMap { Int($0) }.map { $0 * direction },
        )
        guard local.isValidDate(in: utc),
              let wallClock = utc.date(from: local),
              let whole = utc.date(byAdding: toUTC, to: wallClock)
        else {
            return nil
        }
        let fraction = match.7.flatMap { Double("0" + $0) } ?? 0
        return whole.addingTimeInterval(fraction)
    }
}
