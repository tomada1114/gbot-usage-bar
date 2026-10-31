import Foundation

extension UsagePresentation {
    /// The menu line for `error`, or `nil` for a cancellation, which is not a failure.
    static func line(for error: UsageError) -> LocalizedStringResource? {
        switch error {
        case .cancelled:
            nil

        case .noCachedUsage:
            LocalizedStringResource(
                "failure.noCachedUsage",
                defaultValue: "No saved usage — open the desktop app and sign in",
                bundle: .module,
                comment: "Menu line when the desktop app has saved no usage for a signed-in account.",
            )

        case .cacheUnreadable:
            LocalizedStringResource(
                "failure.cacheUnreadable",
                defaultValue: "Couldn’t read the desktop app’s usage cache",
                bundle: .module,
                comment: "Menu line when a cache file exists but could not be read.",
            )

        case .unexpectedFormat:
            LocalizedStringResource(
                "failure.unexpectedFormat",
                defaultValue: "Unexpected usage cache format",
                bundle: .module,
                comment: "Menu line when the desktop app's cache holds something this app cannot read.",
            )

        case .outOfDate:
            LocalizedStringResource(
                "failure.outOfDate",
                defaultValue: "Usage may be out of date — open the desktop app to refresh it",
                bundle: .module,
                comment: "Menu line when the cached usage is expired or from before the weekly reset.",
            )
        }
    }
}
