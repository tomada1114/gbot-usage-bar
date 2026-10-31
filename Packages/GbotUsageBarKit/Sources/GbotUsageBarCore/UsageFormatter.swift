import Foundation

/// Turns the numbers and dates the menu shows into text for one locale and time zone.
///
/// Both are injected rather than read (`designing-core-logic` › Inject locale), so a test
/// pins the exact text; the app passes the auto-updating current ones, which follow a
/// change in System Settings or a trip across time zones without a relaunch.
public struct UsageFormatter: Sendable {
    /// The locale numbers, weekday names, and the 12- or 24-hour clock follow.
    public let locale: Locale
    /// The calendar dates are shown in; its `timeZone` decides the wall-clock time.
    public let calendar: Calendar

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    public init(locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent) {
        self.locale = locale
        self.calendar = calendar
    }

    /// A whole percentage, such as `76%` (`76 %` in German).
    func percent(_ value: Int) -> String {
        value.formatted(.percent.locale(locale))
    }

    /// A weekday, a date, and a time, such as `Sat 7 Nov at 09:58` — for the weekly reset,
    /// which is up to a week away.
    func dateAndTime(_ date: Date) -> String {
        date.formatted(style.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    /// A weekday and a time, such as `Wed 21:00` — for an update earlier this week.
    func weekdayAndTime(_ date: Date) -> String {
        date.formatted(style.weekday(.abbreviated).hour().minute())
    }

    /// A time of day, such as `21:00` — for an update earlier today.
    func time(_ date: Date) -> String {
        date.formatted(style.hour().minute())
    }
}
