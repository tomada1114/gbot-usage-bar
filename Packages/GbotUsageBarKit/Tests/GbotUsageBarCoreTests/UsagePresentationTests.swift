import Foundation
import GbotUsageBarCore
import Testing

/// Every word and number the menu bar and the menu show, per state.
@MainActor
@Suite("UsagePresentation")
struct UsagePresentationTests {
    /// 2026-11-07T12:00:00Z, a Saturday, worked out by hand.
    static let weeklyReset = Date(timeIntervalSince1970: 1_794_052_800)
    /// 2026-11-07T09:00:00Z, the same day as ``updatedToday``.
    static let now = Date(timeIntervalSince1970: 1_794_042_000)
    /// 2026-11-07T08:30:00Z.
    static let updatedToday = Date(timeIntervalSince1970: 1_794_040_200)
    /// 2026-11-05T14:05:00Z, a Thursday.
    static let updatedThursday = Date(timeIntervalSince1970: 1_793_887_500)

    static let weekly = UsageWindow(utilization: 75.6, resetsAt: weeklyReset)

    static func formatter(_ locale: String, zone: String) -> UsageFormatter {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? calendar.timeZone
        return UsageFormatter(locale: Locale(identifier: locale), calendar: calendar)
    }

    static func presentation(_ state: UsageState, formatter: UsageFormatter) -> UsagePresentation {
        UsagePresentation(state: state, formatter: formatter, now: now)
    }

    /// In British English and UTC, whose 24-hour times make the expected text short.
    static func presentation(_ state: UsageState) -> UsagePresentation {
        presentation(state, formatter: formatter("en_GB", zone: "UTC"))
    }

    static func english(_ resource: LocalizedStringResource?) -> String? {
        resource?.resolved(in: .english)
    }

    // MARK: - Before any numbers

    @Test
    func `before the first refresh everything reads as unknown`() {
        let shown = Self.presentation(UsageState())
        #expect(shown.badgeText == "--")
        #expect(Self.english(shown.badgeAccessibilityLabel) == "Weekly usage unavailable")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: --")
        #expect(shown.weeklyReset == nil)
        #expect(shown.failure == nil)
        #expect(shown.updated == nil)
    }

    // MARK: - Warning mark

    @Test
    func `the badge carries no warning while the last read succeeded`() {
        #expect(!Self.presentation(UsageState()).badgeShowsWarning)
        #expect(!Self.presentation(UsageState(weekly: Self.weekly)).badgeShowsWarning)
    }

    @Test(arguments: [UsageError.noCachedUsage, .cacheUnreadable, .unexpectedFormat, .outOfDate])
    func `the badge carries a warning whenever the last read failed, numbers or not`(
        error: UsageError,
    ) {
        #expect(Self.presentation(UsageState(failure: error)).badgeShowsWarning)
        #expect(Self.presentation(UsageState(weekly: Self.weekly, failure: error))
            .badgeShowsWarning)
    }

    // MARK: - With numbers

    @Test
    func `a reading shows its rounded percentage, reset date and time, and update time`() {
        let shown = Self.presentation(UsageState(
            weekly: Self.weekly,
            lastUpdated: Self.updatedToday,
        ))
        #expect(shown.badgeText == "76")
        #expect(Self.english(shown.badgeAccessibilityLabel) == "Weekly usage 76 percent")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: 76%")
        #expect(Self.english(shown.weeklyReset) == "Resets Sat 7 Nov at 12:00")
        #expect(Self.english(shown.updated) == "Updated 08:30")
        #expect(shown.failure == nil)
    }

    @Test
    func `an update from another day carries its weekday`() {
        let shown = Self.presentation(UsageState(
            weekly: Self.weekly,
            lastUpdated: Self.updatedThursday,
        ))
        #expect(Self.english(shown.updated) == "Updated Thu 14:05")
    }

    @Test
    func `times are shown in the formatter's time zone`() {
        let shown = Self.presentation(
            UsageState(weekly: Self.weekly, lastUpdated: Self.updatedToday),
            formatter: Self.formatter("en_GB", zone: "Asia/Tokyo"),
        )
        #expect(Self.english(shown.weeklyReset) == "Resets Sat 7 Nov at 21:00")
        #expect(Self.english(shown.updated) == "Updated 17:30")
    }

    @Test
    func `numbers and times follow the formatter's locale`() {
        let state = UsageState(weekly: Self.weekly, lastUpdated: Self.updatedToday)
        let american = Self.presentation(
            state,
            formatter: Self.formatter("en_US_POSIX", zone: "UTC"),
        )
        #expect(Self.english(american.updated) == "Updated 8:30\u{202F}AM")
        let german = Self.presentation(state, formatter: Self.formatter("de_DE", zone: "UTC"))
        #expect(Self.english(german.weeklyUsage) == "Weekly: 76\u{A0}%")
        #expect(german.badgeText == "76")
    }

    @Test
    func `a window without a reset time shows no reset line`() {
        let shown = Self.presentation(UsageState(weekly: UsageWindow(
            utilization: 100,
            resetsAt: nil,
        )))
        #expect(shown.badgeText == "100")
        #expect(shown.weeklyReset == nil)
    }

    @Test(arguments: [(0.0, "0"), (2.77, "3"), (42.0, "42"), (123.0, "123"), (-4.0, "0")])
    func `the badge is the bare number`(utilization: Double, expected: String) {
        let window = UsageWindow(utilization: utilization, resetsAt: nil)
        #expect(Self.presentation(UsageState(weekly: window)).badgeText == expected)
    }

    // MARK: - Failures

    @Test(arguments: [
        (UsageError.noCachedUsage, "No saved usage — open the desktop app and sign in"),
        (.cacheUnreadable, "Couldn’t read the desktop app’s usage cache"),
        (.unexpectedFormat, "Unexpected usage cache format"),
        (.outOfDate, "Usage may be out of date — open the desktop app to refresh it"),
    ])
    func `each failure has its own line`(error: UsageError, expected: String) {
        let shown = Self.presentation(UsageState(failure: error))
        #expect(Self.english(shown.failure) == expected)
    }

    @Test
    func `a cancellation is not a failure line`() {
        #expect(Self.presentation(UsageState(failure: .cancelled)).failure == nil)
    }

    @Test
    func `a failure keeps showing the last good numbers`() {
        let shown = Self.presentation(
            UsageState(weekly: Self.weekly, failure: .outOfDate, lastUpdated: Self.updatedToday),
        )
        #expect(shown.badgeText == "76")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: 76%")
        #expect(Self.english(shown.updated) == "Updated 08:30")
        #expect(shown.failure != nil)
    }

    @Test
    func `the quit item names the app`() {
        #expect(Self.english(UsagePresentation.quitTitle) == "Quit GbotUsageBar")
    }
}
