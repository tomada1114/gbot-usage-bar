/// Why the usage numbers could not be refreshed — the menu shows a different line for
/// each case, which is why this is an enum and not a message string.
///
/// Every port in the usage story throws exactly this type (`throws(UsageError)`), so the
/// view model's `switch` over it is exhaustive and a new case is a compile error at each
/// place that has to decide what it means. No case carries the token, a response body,
/// or anything else read from the keychain or the network.
public enum UsageError: Error, Equatable, Sendable {
    /// The refresh was cancelled before it finished. Not a failure: the caller keeps
    /// whatever it showed before, and nothing is logged.
    case cancelled
    /// The keychain item could not be read at all — the `security` tool could not run,
    /// or failed for a reason other than a missing item. `status` is its exit status, or
    /// `nil` when it never started; it is for logs only.
    case credentialsUnreadable(status: Int32?)
    /// Claude Code's keychain item is missing, or holds no access token.
    case notSignedIn
    /// The endpoint refused the token (HTTP 401 or 403). Claude Code refreshes its token
    /// when it runs; this app never does.
    case tokenExpired
    /// An HTTP answer this app cannot use: an unexpected status, or a body that is not
    /// the JSON object it expects. `statusCode` is `nil` when the answer was not HTTP.
    case unexpectedResponse(statusCode: Int?)
    /// The request never got an HTTP answer: offline, DNS, TLS, or a timeout.
    case unreachable
}
