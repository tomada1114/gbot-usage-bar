import ClaudeUsageBarCore
import SwiftUI

/// The menu's items for one presentation. Under `.menuBarExtraStyle(.menu)` each `Text`
/// becomes a disabled menu item and each `Divider` a separator.
struct UsageMenuItems: View {
    let presentation: UsagePresentation
    let showInMenuBar: (BadgeWindow) -> Void
    let quit: () -> Void

    var body: some View {
        Text(presentation.weeklyUsage)
        if let weeklyReset = presentation.weeklyReset {
            Text(weeklyReset)
        }
        Divider()
        Text(presentation.fiveHourUsage)
        if let fiveHourReset = presentation.fiveHourReset {
            Text(fiveHourReset)
        }
        Divider()
        Text(UsagePresentation.badgeWindowHeading)
        ForEach(BadgeWindow.menuOrder, id: \.self) { window in
            // A menu renders a Toggle as an item with a checkmark when on.
            Toggle(UsagePresentation.title(for: window), isOn: Binding(
                get: { presentation.badgeWindow == window },
                set: { _ in showInMenuBar(window) },
            ))
        }
        Divider()
        if let failure = presentation.failure {
            Text(failure)
        }
        if let updated = presentation.updated {
            Text(updated)
        }
        Button(UsagePresentation.quitTitle, action: quit)
            .keyboardShortcut("q")
    }
}

@MainActor
private enum PreviewState {
    static let now = Date.now
    static let secondsPerMinute: TimeInterval = 60
    static let minutesPerHour: TimeInterval = 60
    static let secondsPerHour = minutesPerHour * secondsPerMinute
    static let fiveHourPercent: Double = 19
    static let weeklyPercent: Double = 76
    static let hoursToFiveHourReset: TimeInterval = 2
    static let hoursToWeeklyReset: TimeInterval = 48
    static let minutesSinceStaleUpdate: TimeInterval = 10
    static let snapshot = UsageSnapshot(
        fiveHour: UsageWindow(
            utilization: fiveHourPercent,
            resetsAt: now.addingTimeInterval(hoursToFiveHourReset * secondsPerHour),
        ),
        sevenDay: UsageWindow(
            utilization: weeklyPercent,
            resetsAt: now.addingTimeInterval(hoursToWeeklyReset * secondsPerHour),
        ),
    )

    static func items(_ state: UsageState) -> some View {
        VStack(alignment: .leading) {
            UsageMenuItems(presentation: UsagePresentation(
                state: state,
                formatter: UsageFormatter(),
            )) { _ in
                // A preview keeps its badge window.
            } quit: {
                // A preview has nothing to quit.
            }
        }
        .padding()
    }
}

/// The app's menu: the weekly and five-hour usage, which of them the badge shows, why
/// the last refresh failed if it did, when the numbers arrived, and Quit.
public struct UsageMenu: View {
    private let model: UsageMenuViewModel

    public var body: some View {
        UsageMenuItems(presentation: model.presentation) { window in
            model.showInMenuBar(window)
        } quit: {
            model.quit()
        }
    }

    /// `App/` builds the model, because its ports need `ClaudeUsageBarPlatform`'s adapters.
    public init(model: UsageMenuViewModel) {
        self.model = model
    }
}

#Preview("With numbers") {
    PreviewState.items(UsageState(snapshot: PreviewState.snapshot, lastUpdated: PreviewState.now))
}

#Preview("Stale numbers after a failure") {
    PreviewState.items(UsageState(
        snapshot: PreviewState.snapshot,
        failure: .tokenExpired,
        lastUpdated: PreviewState.now
            .addingTimeInterval(-PreviewState.minutesSinceStaleUpdate * PreviewState
                .secondsPerMinute),
    ))
}

#Preview("Not signed in") {
    PreviewState.items(UsageState(failure: .notSignedIn))
}

#Preview("Before the first refresh") {
    PreviewState.items(UsageState())
}
