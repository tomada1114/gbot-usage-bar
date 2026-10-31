/// A port: "what does the usage endpoint answer for this token?"
///
/// `ClaudeUsageBarPlatform`'s `URLSessionUsageFetcher` sends the request
/// ``UsageEndpoint`` describes; tests substitute `FakeUsageFetcher`. The adapter only
/// carries the answer across: what a status or a body means is
/// ``UsageResponse/snapshot()``'s decision, in Core.
public protocol UsageFetching: Sendable {
    /// Sends one request with `token` and hands back whatever HTTP answer came back.
    ///
    /// Any status is an answer, not an error — a 401 included — and its code is always a
    /// real HTTP status (100–599). The only errors are about getting no HTTP answer at
    /// all: ``UsageError/unreachable``, ``UsageError/unexpectedResponse(statusCode:)``
    /// with a `nil` status for an answer that is not HTTP, and ``UsageError/cancelled``.
    ///
    /// `UsageFetchingContract` in `ClaudeUsageBarTestSupport` checks these clauses against
    /// the fake (`just test`) and the real adapter (`just test-local`); a new clause is
    /// stated here first, then added there.
    func fetchUsage(with token: OAuthAccessToken) async throws(UsageError) -> UsageResponse
}
