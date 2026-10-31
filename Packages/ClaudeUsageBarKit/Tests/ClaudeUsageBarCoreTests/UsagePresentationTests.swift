import ClaudeUsageBarCore
import Foundation
import Testing

/// Every word and number the menu bar and the menu show, per state.
@MainActor
@Suite("UsagePresentation")
struct UsagePresentationTests {
    /// 2026-09-30T12:00:00Z (a Wednesday) and 2026-09-29T22:00:00Z, worked out by hand.
    static let weeklyReset = Date(timeIntervalSince1970: 1_790_769_600)
    static let fiveHourReset = Date(timeIntervalSince1970: 1_790_719_200)
    /// 2026-09-29T14:05:00Z.
    static let updated = Date(timeIntervalSince1970: 1_790_690_700)

    static let snapshot = UsageSnapshot(
        fiveHour: UsageWindow(utilization: 19.4, resetsAt: fiveHourReset),
        sevenDay: UsageWindow(utilization: 75.6, resetsAt: weeklyReset),
    )

    static func formatter(_ locale: String, zone: String) -> UsageFormatter {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? calendar.timeZone
        return UsageFormatter(locale: Locale(identifier: locale), calendar: calendar)
    }

    static func presentation(_ state: UsageState, formatter: UsageFormatter) -> UsagePresentation {
        UsagePresentation(state: state, formatter: formatter)
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
        #expect(Self.english(shown.badgeAccessibilityLabel) == "Claude weekly usage unavailable")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: --")
        #expect(Self.english(shown.fiveHourUsage) == "5-hour: --")
        #expect(shown.weeklyReset == nil)
        #expect(shown.fiveHourReset == nil)
        #expect(shown.failure == nil)
        #expect(shown.updated == nil)
    }

    // MARK: - With numbers

    @Test
    func `a snapshot shows its rounded percentages, reset times, and update time`() {
        let shown = Self.presentation(UsageState(
            snapshot: Self.snapshot,
            failure: nil,
            lastUpdated: Self.updated,
        ))
        #expect(shown.badgeText == "76")
        #expect(Self.english(shown.badgeAccessibilityLabel) == "Claude weekly usage 76 percent")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: 76%")
        #expect(Self.english(shown.weeklyReset) == "Resets Wed 12:00")
        #expect(Self.english(shown.fiveHourUsage) == "5-hour: 19%")
        #expect(Self.english(shown.fiveHourReset) == "Resets 22:00")
        #expect(Self.english(shown.updated) == "Updated 14:05")
        #expect(shown.failure == nil)
    }

    @Test
    func `reset times are shown in the formatter's time zone`() {
        let shown = Self.presentation(
            UsageState(snapshot: Self.snapshot, failure: nil, lastUpdated: Self.updated),
            formatter: Self.formatter("en_GB", zone: "Asia/Tokyo"),
        )
        #expect(Self.english(shown.weeklyReset) == "Resets Wed 21:00")
        #expect(Self.english(shown.fiveHourReset) == "Resets 07:00")
        #expect(Self.english(shown.updated) == "Updated 23:05")
    }

    @Test
    func `numbers and times follow the formatter's locale`() {
        let state = UsageState(snapshot: Self.snapshot, failure: nil, lastUpdated: Self.updated)
        let american = Self.presentation(
            state,
            formatter: Self.formatter("en_US_POSIX", zone: "UTC"),
        )
        #expect(Self.english(american.weeklyReset) == "Resets Wed 12:00\u{202F}PM")
        #expect(Self.english(american.fiveHourReset) == "Resets 10:00\u{202F}PM")
        let german = Self.presentation(state, formatter: Self.formatter("de_DE", zone: "UTC"))
        #expect(Self.english(german.weeklyUsage) == "Weekly: 76\u{A0}%")
        #expect(german.badgeText == "76")
    }

    @Test
    func `a window without a reset time shows no reset line`() {
        let partial = UsageSnapshot(
            fiveHour: UsageWindow(utilization: 0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 100, resetsAt: nil),
        )
        let shown = Self.presentation(UsageState(
            snapshot: partial,
            failure: nil,
            lastUpdated: nil,
        ))
        #expect(shown.badgeText == "100")
        #expect(Self.english(shown.fiveHourUsage) == "5-hour: 0%")
        #expect(shown.weeklyReset == nil)
        #expect(shown.fiveHourReset == nil)
    }

    @Test
    func `a snapshot without a weekly window leaves the badge unknown`() {
        let partial = UsageSnapshot(
            fiveHour: UsageWindow(utilization: 19, resetsAt: nil),
            sevenDay: nil,
        )
        let shown = Self.presentation(UsageState(
            snapshot: partial,
            failure: nil,
            lastUpdated: Self.updated,
        ))
        #expect(shown.badgeText == "--")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: --")
        #expect(Self.english(shown.fiveHourUsage) == "5-hour: 19%")
    }

    @Test(arguments: [(0.0, "0"), (5.0, "5"), (42.0, "42"), (123.0, "123"), (-4.0, "0")])
    func `the badge is the bare number`(utilization: Double, expected: String) {
        let partial = UsageSnapshot(
            fiveHour: nil,
            sevenDay: UsageWindow(utilization: utilization, resetsAt: nil),
        )
        #expect(Self.presentation(UsageState(snapshot: partial, failure: nil, lastUpdated: nil))
            .badgeText == expected)
    }

    // MARK: - Failures

    @Test(arguments: [
        (UsageError.notSignedIn, "Not signed in to Claude Code"),
        (
            .credentialsUnreadable(status: 36),
            "Couldn’t read Claude Code’s sign-in from the keychain",
        ),
        (.tokenExpired, "Sign-in expired — open Claude Code to refresh it"),
        (.unreachable, "Couldn’t reach the usage server"),
        (.unexpectedResponse(statusCode: 500), "Unexpected response from the usage server"),
        (.unexpectedResponse(statusCode: nil), "Unexpected response from the usage server"),
    ])
    func `each failure has its own line`(error: UsageError, expected: String) {
        let shown = Self.presentation(UsageState(snapshot: nil, failure: error, lastUpdated: nil))
        #expect(Self.english(shown.failure) == expected)
    }

    @Test
    func `a cancellation is not a failure line`() {
        #expect(Self.presentation(UsageState(snapshot: nil, failure: .cancelled, lastUpdated: nil))
            .failure == nil)
    }

    @Test
    func `a failure keeps showing the last good numbers`() {
        let shown = Self.presentation(
            UsageState(snapshot: Self.snapshot, failure: .unreachable, lastUpdated: Self.updated),
        )
        #expect(shown.badgeText == "76")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: 76%")
        #expect(Self.english(shown.updated) == "Updated 14:05")
        #expect(shown.failure != nil)
    }

    @Test
    func `the quit item names the app`() {
        #expect(Self.english(UsagePresentation.quitTitle) == "Quit ClaudeUsageBar")
    }

    // MARK: - Badge window

    @Test
    func `the five-hour badge shows the five-hour percentage`() {
        let shown = UsagePresentation(
            state: UsageState(snapshot: Self.snapshot, failure: nil, lastUpdated: Self.updated),
            formatter: Self.formatter("en_GB", zone: "UTC"),
            badgeWindow: .fiveHour,
        )
        #expect(shown.badgeWindow == .fiveHour)
        #expect(shown.badgeText == "19")
        #expect(Self.english(shown.badgeAccessibilityLabel) == "Claude 5-hour usage 19 percent")
        #expect(Self.english(shown.weeklyUsage) == "Weekly: 76%")
    }

    @Test
    func `a snapshot without a five-hour window leaves the five-hour badge unknown`() {
        let partial = UsageSnapshot(
            fiveHour: nil,
            sevenDay: UsageWindow(utilization: 76, resetsAt: nil),
        )
        let shown = UsagePresentation(
            state: UsageState(snapshot: partial),
            formatter: Self.formatter("en_GB", zone: "UTC"),
            badgeWindow: .fiveHour,
        )
        #expect(shown.badgeText == "--")
        #expect(Self.english(shown.badgeAccessibilityLabel) == "Claude 5-hour usage unavailable")
    }

    @Test
    func `the badge window choice has a heading and a title per window`() {
        #expect(BadgeWindow.menuOrder == [.weekly, .fiveHour])
        #expect(Self.english(UsagePresentation.badgeWindowHeading) == "Show in Menu Bar")
        #expect(Self.english(UsagePresentation.title(for: .weekly)) == "Weekly")
        #expect(Self.english(UsagePresentation.title(for: .fiveHour)) == "5-hour")
    }
}
