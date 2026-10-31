import ClaudeUsageBarCore
import ClaudeUsageBarPlatform
import ClaudeUsageBarUI
import SwiftUI

/// Application entry point — wiring only. All real code lives in Packages/ClaudeUsageBarKit.
///
/// A menu-bar agent: `LSUIElement` keeps it out of the Dock and the app switcher, so
/// `MenuBarExtra` is the whole user interface (`docs/architecture/adr/0001-app-shape.md`).
/// The `.menu` style renders the content as a native menu of `Text`, `Divider`, and
/// `Button` items.
///
/// This is also the composition root: the one place that knows both halves of each
/// port. It builds the `ClaudeUsageBarPlatform` adapters, hands them to the Core view
/// model, and starts its polling once, here, so the badge fills in at launch rather than
/// on the first click.
@main
struct ClaudeUsageBarApp: App {
    @State private var usage: UsageMenuViewModel

    var body: some Scene {
        MenuBarExtra {
            UsageMenu(model: usage)
        } label: {
            UsageBadgeLabel(model: usage)
        }
        .menuBarExtraStyle(.menu)
    }

    init() {
        let tuning = Tuning.default
        let model = UsageMenuViewModel(
            ports: UsageMenuViewModel.Ports(
                tokenProvider: SecurityCLITokenProvider(),
                usageFetcher: URLSessionUsageFetcher(timeout: tuning.requestTimeout),
                terminator: NSApplicationTerminator(),
            ),
            tuning: tuning,
        )
        model.startPolling()
        _usage = State(initialValue: model)
    }
}
