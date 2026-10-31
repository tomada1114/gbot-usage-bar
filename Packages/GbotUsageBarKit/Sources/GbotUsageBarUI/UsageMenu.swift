import GbotUsageBarCore
import SwiftUI

/// The menu's items for one presentation. Under `.menuBarExtraStyle(.menu)` each `Text`
/// becomes a disabled menu item and each `Divider` a separator.
struct UsageMenuItems: View {
    let presentation: UsagePresentation
    let quit: () -> Void

    var body: some View {
        Text(presentation.weeklyUsage)
        if let weeklyReset = presentation.weeklyReset {
            Text(weeklyReset)
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
    static let weeklyPercent: Double = 76
    static let hoursToWeeklyReset: TimeInterval = 48
    static let minutesSinceStaleUpdate: TimeInterval = 10
    static let weekly = UsageWindow(
        utilization: weeklyPercent,
        resetsAt: now.addingTimeInterval(hoursToWeeklyReset * secondsPerHour),
    )

    static func items(_ state: UsageState) -> some View {
        VStack(alignment: .leading) {
            UsageMenuItems(presentation: UsagePresentation(
                state: state,
                formatter: UsageFormatter(),
                now: now,
            )) {
                // A preview has nothing to quit.
            }
        }
        .padding()
    }
}

/// The app's menu: the weekly usage and when it resets, why the last refresh failed if
/// it did, when the numbers were read, and Quit.
public struct UsageMenu: View {
    private let model: UsageMenuViewModel

    public var body: some View {
        UsageMenuItems(presentation: model.presentation) {
            model.quit()
        }
    }

    /// `App/` builds the model, because its ports need `GbotUsageBarPlatform`'s adapters.
    public init(model: UsageMenuViewModel) {
        self.model = model
    }
}

#Preview("With numbers") {
    PreviewState.items(UsageState(weekly: PreviewState.weekly, lastUpdated: PreviewState.now))
}

#Preview("Stale numbers after a failure") {
    PreviewState.items(UsageState(
        weekly: PreviewState.weekly,
        failure: .outOfDate,
        lastUpdated: PreviewState.now
            .addingTimeInterval(-PreviewState.minutesSinceStaleUpdate * PreviewState
                .secondsPerMinute),
    ))
}

#Preview("No saved usage") {
    PreviewState.items(UsageState(failure: .noCachedUsage))
}

#Preview("Before the first refresh") {
    PreviewState.items(UsageState())
}
