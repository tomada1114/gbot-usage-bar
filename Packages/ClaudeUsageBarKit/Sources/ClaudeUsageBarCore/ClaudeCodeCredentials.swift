import Foundation

/// The `claudeAiOauth` object inside the credentials JSON.
private struct OAuthPayload: Decodable {
    let accessToken: String?
}

/// The credentials JSON, reduced to the one object this app reads.
private struct CredentialsPayload: Decodable {
    let claudeAiOauth: OAuthPayload?
}

/// The JSON Claude Code stores in its `Claude Code-credentials` keychain item.
public enum ClaudeCodeCredentials {
    /// The keychain service name Claude Code stores its credentials under.
    public static let keychainService = "Claude Code-credentials"

    /// Reads `claudeAiOauth.accessToken` from the keychain item's JSON, ignoring every
    /// other key (the refresh token among them, which this app never reads).
    ///
    /// - Throws: ``UsageError/notSignedIn`` when the payload is not that JSON or holds
    ///   no non-blank token — either way, Claude Code has not signed in on this Mac.
    public static func accessToken(from payload: Data) throws(UsageError) -> OAuthAccessToken {
        guard let credentials = try? JSONDecoder().decode(CredentialsPayload.self, from: payload),
              let token = credentials.claudeAiOauth?.accessToken,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw .notSignedIn
        }
        return OAuthAccessToken(token)
    }
}
