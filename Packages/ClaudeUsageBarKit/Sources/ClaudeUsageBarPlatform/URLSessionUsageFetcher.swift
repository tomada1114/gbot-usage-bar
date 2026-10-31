import ClaudeUsageBarCore
import Foundation

/// The `URLSession`-backed adapter for ``ClaudeUsageBarCore/UsageFetching``.
///
/// It sends the one request ``ClaudeUsageBarCore/UsageEndpoint`` describes and hands back
/// the status and body untouched; what they mean is
/// ``ClaudeUsageBarCore/UsageResponse/snapshot()``'s decision. Only getting no HTTP answer
/// is translated here: a cancelled request becomes
/// ``ClaudeUsageBarCore/UsageError/cancelled``, every other `URLError` (offline, DNS, TLS,
/// a timeout) ``ClaudeUsageBarCore/UsageError/unreachable``. Checked by
/// `URLSessionUsageFetcherTests` under `just test-local`.
public struct URLSessionUsageFetcher: UsageFetching {
    private let session: URLSession
    private let timeout: TimeInterval

    /// - Parameters:
    ///   - timeout: How long one request may take, from ``ClaudeUsageBarCore/Tuning``.
    ///   - session: The session to send on; `.shared` by default.
    public init(timeout: Duration, session: URLSession = .shared) {
        self.session = session
        self.timeout = TimeInterval(timeout.components.seconds)
    }

    public func fetchUsage(with token: OAuthAccessToken) async throws(UsageError) -> UsageResponse {
        var request = URLRequest(
            url: UsageEndpoint.url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout,
        )
        for (field, value) in UsageEndpoint.headers(for: token) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let answer: (Data, URLResponse)
        do {
            answer = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw .cancelled
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .unreachable
        }
        guard let http = answer.1 as? HTTPURLResponse else {
            throw .unexpectedResponse(statusCode: nil)
        }
        return UsageResponse(statusCode: http.statusCode, body: answer.0)
    }
}
