import ClaudeUsageBarCore
import Testing

/// The promises ``ClaudeUsageBarCore/OAuthTokenProviding`` makes, checked against any
/// implementation of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// `ClaudeUsageBarCoreTests` runs ``check(_:)`` against ``FakeOAuthTokenProvider`` on every
/// `just test`; `ClaudeUsageBarPlatformTests` runs it against `SecurityCLITokenProvider`
/// under `.requiresLocalMachine` (`just test-local`). Every clause is one the port's `///`
/// states; a new clause is stated there first.
package enum OAuthTokenProvidingContract {
    /// How many times ``violations(of:)`` asks: the token is read afresh on every
    /// refresh, so a promise kept only by the first answer is not kept.
    static let askCount = 2

    /// A description of every broken promise, empty when `provider` keeps them all.
    package static func violations(of provider: some OAuthTokenProviding) async -> [String] {
        var broken: [String] = []
        for ask in 1 ... askCount {
            do throws(UsageError) {
                let token = try await provider.accessToken()
                if token.value.allSatisfy(\.isWhitespace) {
                    broken.append("answer \(ask) of \(askCount) is a blank token")
                }
            } catch {
                switch error {
                case .cancelled, .credentialsUnreadable, .notSignedIn:
                    break

                case .tokenExpired, .unexpectedResponse, .unreachable:
                    broken
                        .append(
                            "answer \(ask) of \(askCount) throws \(error), which only a fetch may",
                        )
                }
            }
        }
        return broken
    }

    /// Records an issue for every promise `provider` breaks.
    package static func check(_ provider: some OAuthTokenProviding) async {
        let broken = await violations(of: provider)
        #expect(
            broken.isEmpty,
            "\(type(of: provider)) breaks the OAuthTokenProviding contract: \(broken)",
        )
    }
}
