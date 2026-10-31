/// A port: "what is Claude Code's current access token?"
///
/// `ClaudeUsageBarPlatform`'s `SecurityCLITokenProvider` answers it from the keychain item
/// Claude Code keeps; tests substitute `FakeOAuthTokenProvider`; `App/` picks the real
/// one. The token is read afresh on every call and never cached, because Claude Code
/// replaces it whenever it refreshes its sign-in — a cached copy would go stale while the
/// keychain holds a good one.
public protocol OAuthTokenProviding: Sendable {
    /// Claude Code's access token as it is stored right now.
    ///
    /// A returned token is never blank. The only errors are the ones about reading the
    /// token — ``UsageError/notSignedIn``, ``UsageError/credentialsUnreadable(status:)``,
    /// and ``UsageError/cancelled`` — never one about the network.
    ///
    /// `OAuthTokenProvidingContract` in `ClaudeUsageBarTestSupport` checks these clauses
    /// against the fake (`just test`) and the real adapter (`just test-local`); a new
    /// clause is stated here first, then added there.
    func accessToken() async throws(UsageError) -> OAuthAccessToken
}
