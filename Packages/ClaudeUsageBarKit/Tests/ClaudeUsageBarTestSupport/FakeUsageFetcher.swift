import ClaudeUsageBarCore
import os

/// The one fake of ``ClaudeUsageBarCore/UsageFetching``, shared by every test target.
///
/// Answers from the results a test hands it and records the token each call carried, so
/// a test can see that the view model sends what the token port answered.
/// `UsageFetchingContract` holds it to the same promises as the real adapter.
package final class FakeUsageFetcher: UsageFetching {
    /// The token each call to ``fetchUsage(with:)`` carried, in order.
    package var receivedTokens: [OAuthAccessToken] {
        received.withLock { $0 }
    }

    /// How many times ``fetchUsage(with:)`` has been asked so far.
    package var callCount: Int {
        receivedTokens.count
    }

    private let answers: [Result<UsageResponse, UsageError>]
    private let received = OSAllocatedUnfairLock(initialState: [OAuthAccessToken]())

    /// Answers each call in order, repeating the last one once they run out; no answers
    /// at all means every call throws ``UsageError/unreachable``.
    package init(answering answers: [Result<UsageResponse, UsageError>]) {
        self.answers = answers.isEmpty ? [.failure(.unreachable)] : answers
    }

    package func fetchUsage(with token: OAuthAccessToken) throws(UsageError) -> UsageResponse {
        let index = received.withLock { tokens in
            defer { tokens.append(token) }
            return min(tokens.count, answers.count - 1)
        }
        return try answers[index].get()
    }
}
