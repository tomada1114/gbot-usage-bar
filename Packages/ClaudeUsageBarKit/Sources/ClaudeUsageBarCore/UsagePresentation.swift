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
            defaultValue: "Quit ClaudeUsageBar",
            bundle: .module,
            comment: "Menu item that quits the app. ClaudeUsageBar is the app's name.",
        )
    }

    /// The heading above the badge window choice in the menu.
    public static var badgeWindowHeading: LocalizedStringResource {
        LocalizedStringResource(
            "menu.badgeWindow.heading",
            defaultValue: "Show in Menu Bar",
            bundle: .module,
            comment: "Menu heading above the choice of which usage window the menu bar shows.",
        )
    }

    /// The state rendered.
    public let state: UsageState
    /// The locale and time zone the numbers and times are written in.
    public let formatter: UsageFormatter
    /// The window whose percentage the badge shows.
    public let badgeWindow: BadgeWindow

    /// The menu bar text: ``badgeWindow``'s percentage as a bare number, with no `%`, so
    /// the badge stays as narrow as an icon; ``unknownValue`` without one.
    public var badgeText: String {
        badgePercent.map(String.init) ?? Self.unknownValue
    }

    /// What VoiceOver reads for the badge, which on its own is a number without context.
    public var badgeAccessibilityLabel: LocalizedStringResource {
        switch badgeWindow {
        case .weekly:
            weeklyBadgeAccessibilityLabel

        case .fiveHour:
            fiveHourBadgeAccessibilityLabel
        }
    }

    private var weeklyBadgeAccessibilityLabel: LocalizedStringResource {
        guard let percent = weeklyPercent else {
            return LocalizedStringResource(
                "badge.accessibility.unavailable",
                defaultValue: "Claude weekly usage unavailable",
                bundle: .module,
                comment: "VoiceOver label for the menu bar item when the weekly usage is not known yet.",
            )
        }
        return LocalizedStringResource(
            "badge.accessibility",
            defaultValue: "Claude weekly usage \(percent) percent",
            bundle: .module,
            comment: "VoiceOver label for the menu bar item. The argument is the weekly usage, a whole percentage.",
        )
    }

    private var fiveHourBadgeAccessibilityLabel: LocalizedStringResource {
        guard let percent = fiveHourPercent else {
            return LocalizedStringResource(
                "badge.accessibility.fiveHour.unavailable",
                defaultValue: "Claude 5-hour usage unavailable",
                bundle: .module,
                comment: "VoiceOver label for the menu bar item when the five-hour usage is not known yet.",
            )
        }
        return LocalizedStringResource(
            "badge.accessibility.fiveHour",
            defaultValue: "Claude 5-hour usage \(percent) percent",
            bundle: .module,
            comment: "VoiceOver label for the menu bar item. The argument is the five-hour usage, a whole percentage.",
        )
    }

    /// The weekly window's line, such as `Weekly: 76%`.
    public var weeklyUsage: LocalizedStringResource {
        guard let percent = weeklyPercent else {
            return LocalizedStringResource(
                "menu.weekly.unavailable",
                defaultValue: "Weekly: --",
                bundle: .module,
                comment: "Menu line for the weekly usage limit when its value is not known yet.",
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

    /// When the weekly window resets, such as `Resets Wed 21:00`; `nil` when unknown.
    public var weeklyReset: LocalizedStringResource? {
        state.snapshot?.sevenDay?.resetsAt.map { Self.resets(formatter.weekdayAndTime($0)) }
    }

    /// The five-hour window's line, such as `5-hour: 19%`.
    public var fiveHourUsage: LocalizedStringResource {
        guard let percent = fiveHourPercent else {
            return LocalizedStringResource(
                "menu.fiveHour.unavailable",
                defaultValue: "5-hour: --",
                bundle: .module,
                comment: "Menu line for the five-hour usage limit when its value is not known yet.",
            )
        }
        let value = formatter.percent(percent)
        return LocalizedStringResource(
            "menu.fiveHour",
            defaultValue: "5-hour: \(value)",
            bundle: .module,
            comment: "Menu line for the five-hour usage limit. The argument is a formatted percentage, such as 19%.",
        )
    }

    /// When the five-hour window resets, such as `Resets 22:00`; `nil` when unknown.
    public var fiveHourReset: LocalizedStringResource? {
        state.snapshot?.fiveHour?.resetsAt.map { Self.resets(formatter.time($0)) }
    }

    /// Why the last refresh failed, or `nil` when it did not.
    public var failure: LocalizedStringResource? {
        state.failure.flatMap(Self.line(for:))
    }

    /// When the numbers shown arrived, such as `Updated 14:05`; `nil` before any did.
    public var updated: LocalizedStringResource? {
        guard let lastUpdated = state.lastUpdated else {
            return nil
        }
        let time = formatter.time(lastUpdated)
        return LocalizedStringResource(
            "menu.updated",
            defaultValue: "Updated \(time)",
            bundle: .module,
            comment: "Menu line saying when the usage was last fetched. The argument is a time of day.",
        )
    }

    private var weeklyPercent: Int? {
        state.snapshot?.sevenDay?.percent
    }

    private var fiveHourPercent: Int? {
        state.snapshot?.fiveHour?.percent
    }

    private var badgePercent: Int? {
        switch badgeWindow {
        case .weekly:
            weeklyPercent

        case .fiveHour:
            fiveHourPercent
        }
    }

    public init(state: UsageState, formatter: UsageFormatter, badgeWindow: BadgeWindow = .weekly) {
        self.state = state
        self.formatter = formatter
        self.badgeWindow = badgeWindow
    }

    /// The menu item that puts `window` in the menu bar.
    public static func title(for window: BadgeWindow) -> LocalizedStringResource {
        switch window {
        case .weekly:
            LocalizedStringResource(
                "menu.badgeWindow.weekly",
                defaultValue: "Weekly",
                bundle: .module,
                comment: "Menu item that makes the menu bar show the weekly usage limit.",
            )

        case .fiveHour:
            LocalizedStringResource(
                "menu.badgeWindow.fiveHour",
                defaultValue: "5-hour",
                bundle: .module,
                comment: "Menu item that makes the menu bar show the five-hour usage limit.",
            )
        }
    }

    private static func resets(_ when: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "menu.resets",
            defaultValue: "Resets \(when)",
            bundle: .module,
            comment: "Line saying when a usage limit resets. The argument is a time, or a weekday and a time.",
        )
    }
}
