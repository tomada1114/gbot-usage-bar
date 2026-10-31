import ClaudeUsageBarCore
import os

/// The one fake of ``ClaudeUsageBarCore/OAuthTokenProviding``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): it answers from
/// the results a test hands it and records how often it was asked.
/// `OAuthTokenProvidingContract` holds it to the same promises as the real adapter.
package final class FakeOAuthTokenProvider: OAuthTokenProviding {
    /// How many times ``accessToken()`` has been asked so far.
    package var callCount: Int {
        calls.withLock { $0 }
    }

    private let answers: [Result<OAuthAccessToken, UsageError>]
    private let calls = OSAllocatedUnfairLock(initialState: 0)

    /// Answers each call in order, repeating the last one once they run out; no answers
    /// at all means every call throws ``UsageError/notSignedIn``.
    package init(answering answers: [Result<OAuthAccessToken, UsageError>]) {
        self.answers = answers.isEmpty ? [.failure(.notSignedIn)] : answers
    }

    package func accessToken() throws(UsageError) -> OAuthAccessToken {
        let index = calls.withLock { count in
            defer { count += 1 }
            return min(count, answers.count - 1)
        }
        return try answers[index].get()
    }
}
