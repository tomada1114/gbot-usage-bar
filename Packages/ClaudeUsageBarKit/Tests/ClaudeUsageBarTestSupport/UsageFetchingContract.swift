import ClaudeUsageBarCore
import Testing

/// The promises ``ClaudeUsageBarCore/UsageFetching`` makes, checked against any
/// implementation of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// `ClaudeUsageBarCoreTests` runs ``check(_:with:)`` against ``FakeUsageFetcher`` on every
/// `just test`; `ClaudeUsageBarPlatformTests` runs it against `URLSessionUsageFetcher`
/// under `.requiresLocalMachine` (`just test-local`). Every clause is one the port's `///`
/// states; a new clause is stated there first.
package enum UsageFetchingContract {
    /// How many times ``violations(of:with:)`` asks: the usage is fetched afresh on every
    /// refresh, so a promise kept only by the first answer is not kept.
    static let askCount = 2

    /// The status codes an HTTP answer can carry.
    static let httpStatusCodes = 100 ... 599

    /// A description of every broken promise, empty when `fetcher` keeps them all.
    package static func violations(
        of fetcher: some UsageFetching,
        with token: OAuthAccessToken,
    ) async -> [String] {
        var broken: [String] = []
        for ask in 1 ... askCount {
            do throws(UsageError) {
                let response = try await fetcher.fetchUsage(with: token)
                if !httpStatusCodes.contains(response.statusCode) {
                    broken.append("answer \(ask) of \(askCount) has status \(response.statusCode)")
                }
            } catch {
                switch error {
                case .cancelled, .unexpectedResponse(statusCode: nil), .unreachable:
                    break

                case .credentialsUnreadable, .notSignedIn, .tokenExpired, .unexpectedResponse:
                    broken.append("answer \(ask) of \(askCount) throws \(error)")
                }
            }
        }
        return broken
    }

    /// Records an issue for every promise `fetcher` breaks.
    package static func check(_ fetcher: some UsageFetching, with token: OAuthAccessToken) async {
        let broken = await violations(of: fetcher, with: token)
        #expect(broken.isEmpty, "\(type(of: fetcher)) breaks the UsageFetching contract: \(broken)")
    }
}
