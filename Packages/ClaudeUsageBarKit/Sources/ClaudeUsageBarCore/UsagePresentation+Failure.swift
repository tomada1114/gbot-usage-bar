import Foundation

extension UsagePresentation {
    /// The menu line for `error`, or `nil` for a cancellation, which is not a failure.
    static func line(for error: UsageError) -> LocalizedStringResource? {
        switch error {
        case .cancelled:
            nil

        case .notSignedIn:
            LocalizedStringResource(
                "failure.notSignedIn",
                defaultValue: "Not signed in to Claude Code",
                bundle: .module,
                comment: "Menu line when Claude Code's credentials are not in the keychain.",
            )

        case .credentialsUnreadable:
            LocalizedStringResource(
                "failure.credentialsUnreadable",
                defaultValue: "Couldn’t read Claude Code’s sign-in from the keychain",
                bundle: .module,
                comment: "Menu line when the keychain item holding Claude Code's credentials could not be read.",
            )

        case .tokenExpired:
            LocalizedStringResource(
                "failure.tokenExpired",
                defaultValue: "Sign-in expired — open Claude Code to refresh it",
                bundle: .module,
                comment: "Menu line when the server rejects Claude Code's token. Running Claude Code renews it.",
            )

        case .unreachable:
            LocalizedStringResource(
                "failure.unreachable",
                defaultValue: "Couldn’t reach the usage server",
                bundle: .module,
                comment: "Menu line when the usage request got no answer: offline, or a timeout.",
            )

        case .unexpectedResponse:
            LocalizedStringResource(
                "failure.unexpectedResponse",
                defaultValue: "Unexpected response from the usage server",
                bundle: .module,
                comment: "Menu line when the server answered with something the app cannot read.",
            )
        }
    }
}
