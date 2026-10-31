/// Claude Code's OAuth access token, wrapped so it cannot leak by accident.
///
/// Its description, debug description, and mirror all read `<redacted>`, so a log line,
/// a test failure, or a `dump` that interpolates the token by mistake shows nothing.
/// ``value`` is read in exactly one place: ``UsageEndpoint/headers(for:)``.
public struct OAuthAccessToken: Equatable, Sendable {
    /// The bearer token itself. Never log it, and never put it in an error.
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

extension OAuthAccessToken: CustomStringConvertible {
    public var description: String {
        "<redacted>"
    }
}

extension OAuthAccessToken: CustomDebugStringConvertible {
    public var debugDescription: String {
        description
    }
}

extension OAuthAccessToken: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(self, children: [], displayStyle: .struct)
    }
}
