import ClaudeUsageBarCore
import ClaudeUsageBarPlatform
import ClaudeUsageBarTestSupport
import Foundation
import Testing

/// `URLSessionUsageFetcher` against the real endpoint, which a CI runner has no token for.
///
/// Needs network access; the signed-in test also needs Claude Code signed in on this Mac
/// with a current token (running Claude Code refreshes it).
@Suite("URLSessionUsageFetcher against the real endpoint", .requiresLocalMachine)
struct URLSessionUsageFetcherTests {
    static let fetcher = URLSessionUsageFetcher(timeout: Tuning.default.requestTimeout)

    /// The endpoint answers an invalid token with 401, or with 429 once it has seen a few
    /// in a row (observed 2026-09-29) — either way an HTTP answer the adapter must pass on
    /// rather than throw, and one Core reads as a failure.
    @Test
    func `an invalid token gets an HTTP answer, not a thrown error`() async throws {
        let response = try await Self.fetcher.fetchUsage(with: OAuthAccessToken("invalid-token"))
        #expect([401, 429].contains(response.statusCode), "status \(response.statusCode)")
        #expect(throws: UsageError.self) {
            try response.snapshot()
        }
    }

    @Test
    func `the signed-in token gets a snapshot with a weekly window`() async throws {
        let token = try await SecurityCLITokenProvider().accessToken()
        let response = try await Self.fetcher.fetchUsage(with: token)
        let snapshot = try response.snapshot()
        let weekly = try #require(snapshot.sevenDay, "the response has no seven_day window")
        #expect((0 ... 100).contains(weekly.utilization))
        #expect(weekly.resetsAt != nil)
    }

    @Test
    func `keeps the UsageFetching contract the fake is held to`() async {
        await UsageFetchingContract.check(Self.fetcher, with: OAuthAccessToken("invalid-token"))
    }
}
