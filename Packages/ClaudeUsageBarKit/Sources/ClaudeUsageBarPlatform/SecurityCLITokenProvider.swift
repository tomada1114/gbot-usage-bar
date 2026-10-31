import ClaudeUsageBarCore
import Foundation

/// What running `security` came to.
private enum Outcome: Sendable {
    case exited(status: Int32, output: Data)
    case launchFailed
}

/// The `/usr/bin/security`-backed adapter for ``ClaudeUsageBarCore/OAuthTokenProviding``.
///
/// It runs `security find-generic-password -s "Claude Code-credentials" -w` and hands
/// the item's JSON to ``ClaudeUsageBarCore/ClaudeCodeCredentials/accessToken(from:)``.
///
/// **Why a subprocess rather than `SecItemCopyMatching`.** The keychain item belongs to
/// Claude Code, so this app reading it through the Security framework is not on the
/// item's access list and macOS would ask the user to allow it — and ask again after each
/// rebuild of an ad-hoc-signed app. Observed on the owner's Mac (not checked against the
/// item's access list itself): `/usr/bin/security` reads the item without a prompt, as
/// the owner's existing status-line script does, which suggests the item's access list
/// already trusts that tool. The price is the App Sandbox: a sandboxed process cannot
/// read another application's keychain item
/// (`docs/architecture/adr/0002-sandbox-posture.md`, `0003-usage-data-source.md`).
///
/// Translation only: exit status 44 (`errSecItemNotFound`) becomes
/// ``ClaudeUsageBarCore/UsageError/notSignedIn``, any other failure
/// ``ClaudeUsageBarCore/UsageError/credentialsUnreadable(status:)``, and parsing the JSON
/// is Core's. The command's output holds the token and a refresh token, so it is never
/// logged, and its standard error is discarded unread. Checked by
/// `SecurityCLITokenProviderTests` under `just test-local`.
public struct SecurityCLITokenProvider: OAuthTokenProviding {
    /// `security`'s exit status for a missing item — `errSecItemNotFound` truncated to its
    /// low byte, as the tool reports it.
    static let itemNotFoundStatus: Int32 = 44

    private let service: String

    /// Reads the item stored under `service`, Claude Code's by default; a test passes a
    /// service that does not exist to see the not-found translation.
    public init(service: String = ClaudeCodeCredentials.keychainService) {
        self.service = service
    }

    /// Runs `security` with `arguments` to completion and returns its exit status and
    /// standard output.
    private static func run(_ arguments: [String]) -> Outcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return .launchFailed
        }
        // Read to the end before waiting: a child blocked on a full pipe never exits.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return .exited(status: process.terminationStatus, output: data)
    }

    public func accessToken() async throws(UsageError) -> OAuthAccessToken {
        let arguments = ["find-generic-password", "-s", service, "-w"]
        // `Process` blocks until the child exits, so it runs on a Dispatch thread rather
        // than on the cooperative pool Swift concurrency shares with the rest of the app.
        let outcome = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: Self.run(arguments))
            }
        }
        switch outcome {
        case .launchFailed:
            throw .credentialsUnreadable(status: nil)

        case let .exited(status, _) where status == Self.itemNotFoundStatus:
            throw .notSignedIn

        case let .exited(status, _) where status != 0:
            throw .credentialsUnreadable(status: status)

        case let .exited(_, output):
            return try ClaudeCodeCredentials.accessToken(from: output)
        }
    }
}
