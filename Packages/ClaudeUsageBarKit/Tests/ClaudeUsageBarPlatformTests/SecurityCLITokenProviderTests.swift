import ClaudeUsageBarCore
import ClaudeUsageBarPlatform
import ClaudeUsageBarTestSupport
import Foundation
import Testing

/// `SecurityCLITokenProvider` against the real `/usr/bin/security` and the login keychain.
///
/// Needs Claude Code signed in on this Mac, so its `Claude Code-credentials` item exists,
/// and an unsandboxed test process — `swift test` is one. No assertion prints the token:
/// `OAuthAccessToken` describes itself as `<redacted>`, and only its length is checked.
@Suite("SecurityCLITokenProvider against the real keychain", .requiresLocalMachine)
struct SecurityCLITokenProviderTests {
    @Test
    func `reads Claude Code's access token`() async {
        let token: OAuthAccessToken
        do {
            token = try await SecurityCLITokenProvider().accessToken()
        } catch {
            Issue.record("""
            reading the token failed with \(error). This test needs Claude Code signed in \
            on this Mac (run `claude` and log in), then rerun `just test-local`.
            """)
            return
        }
        #expect(token.value.count > 20, "the token is implausibly short")
        #expect(token.value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil)
    }

    @Test
    func `a service with no keychain item translates to not signed in`() async {
        let provider = SecurityCLITokenProvider(service: "ClaudeUsageBarTests-\(UUID().uuidString)")
        await #expect(throws: UsageError.notSignedIn) {
            try await provider.accessToken()
        }
    }

    @Test
    func `keeps the OAuthTokenProviding contract the fake is held to`() async {
        await OAuthTokenProvidingContract.check(SecurityCLITokenProvider())
    }
}
