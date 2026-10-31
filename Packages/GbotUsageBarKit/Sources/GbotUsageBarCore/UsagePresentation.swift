import Foundation

/// Every word and number the menu bar and its menu show for one ``UsageState``.
///
/// A value built from the state and a formatter, so a view renders it without deciding
/// anything and a preview builds any state without a port. Each line is a whole
/// sentence from Core's String Catalog (`localizing-the-app`), built afresh on every read.
public struct UsagePresentation: Sendable {
    /// What the badge and the menu show where a number is unknown.
    public static let unknownValue = "--"

    /// The menu's last item.
    public static var quitTitle: LocalizedStringResource {
        LocalizedStringResource(
            "menu.quit",
            defaultValue: "Quit GbotUsageBar",
            bundle: .module,
            comment: "Menu item that quits the app. GbotUsageBar is the app's name.",
        )
    }

    /// The state rendered.
    public let state: UsageState
    /// The locale and time zone the numbers and times are written in.
    public let formatter: UsageFormatter
    /// The moment the presentation is for, which decides whether the last update is
    /// written as a time alone (today) or with its weekday.
    public let now: Date

    /// The menu bar text: the weekly percentage as a bare number, with no `%`, so the
    /// badge stays as narrow as an icon; ``unknownValue`` without one.
    public var badgeText: String {
        weeklyPercent.map(String.init) ?? Self.unknownValue
    }

    /// Whether the badge carries a warning mark: whenever the last read failed or its
    /// numbers may be stale, so a change in the desktop app's cache shows in the menu bar
    /// itself rather than only inside the menu, where the last good number would hide it.
    public var badgeShowsWarning: Bool {
        state.failure != nil
    }

    /// What VoiceOver reads for the badge, which on its own is a number without context.
    public var badgeAccessibilityLabel: LocalizedStringResource {
        guard let percent = weeklyPercent else {
            return LocalizedStringResource(
                "badge.accessibility.unavailable",
                defaultValue: "Weekly usage unavailable",
                bundle: .module,
                comment: "VoiceOver label for the menu bar item when the weekly usage is not known.",
            )
        }
        return LocalizedStringResource(
            "badge.accessibility",
            defaultValue: "Weekly usage \(percent) percent",
            bundle: .module,
            comment: "VoiceOver label for the menu bar item. The argument is the weekly usage, a whole percentage.",
        )
    }

    /// The weekly window's line, such as `Weekly: 76%`.
    public var weeklyUsage: LocalizedStringResource {
        guard let percent = weeklyPercent else {
            return LocalizedStringResource(
                "menu.weekly.unavailable",
                defaultValue: "Weekly: --",
                bundle: .module,
                comment: "Menu line for the weekly usage limit when its value is not known.",
            )
        }
        let value = formatter.percent(percent)
        return LocalizedStringResource(
            "menu.weekly",
            defaultValue: "Weekly: \(value)",
            bundle: .module,
            comment: "Menu line for the weekly usage limit. The argument is a formatted percentage, such as 76%.",
        )
    }

    /// When the weekly window resets, such as `Resets Sat 7 Nov at 09:58`; `nil` when unknown.
    public var weeklyReset: LocalizedStringResource? {
        guard let resetsAt = state.weekly?.resetsAt else {
            return nil
        }
        let when = formatter.dateAndTime(resetsAt)
        return LocalizedStringResource(
            "menu.resets",
            defaultValue: "Resets \(when)",
            bundle: .module,
            comment: "Line saying when the weekly usage limit resets. The argument is a weekday, a date, and a time.",
        )
    }

    /// Why the last refresh failed, or `nil` when it did not.
    public var failure: LocalizedStringResource? {
        state.failure.flatMap(Self.line(for:))
    }

    /// When the desktop app read the numbers shown, such as `Updated 14:05`, or
    /// `Updated Thu 14:05` when that was not today; `nil` before any read.
    public var updated: LocalizedStringResource? {
        guard let lastUpdated = state.lastUpdated else {
            return nil
        }
        let time = formatter.calendar.isDate(lastUpdated, inSameDayAs: now)
            ? formatter.time(lastUpdated)
            : formatter.weekdayAndTime(lastUpdated)
        return LocalizedStringResource(
            "menu.updated",
            defaultValue: "Updated \(time)",
            bundle: .module,
            comment: "Menu line saying when the usage was last read. The argument is a time, or a weekday and a time.",
        )
    }

    private var weeklyPercent: Int? {
        state.weekly?.percent
    }

    public init(state: UsageState, formatter: UsageFormatter, now: Date) {
        self.state = state
        self.formatter = formatter
        self.now = now
    }
}
