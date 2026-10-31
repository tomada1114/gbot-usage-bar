import Foundation

/// The request the usage adapter sends, spelled once in Core so a test pins it.
///
/// `GET /api/oauth/usage` is an internal endpoint Claude Code itself calls; Anthropic
/// does not document it, so its path, its beta header, and its JSON can change without
/// notice (`docs/architecture/adr/0003-usage-data-source.md`).
public enum UsageEndpoint {
    /// The endpoint's URL. The literal is well formed, so the fallback is unreachable;
    /// it exists only because `URL(string:)` is failable and a force unwrap is not
    /// allowed. `UsageEndpointTests` pins the real value.
    public static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")
        ?? URL(fileURLWithPath: "/")

    /// The value of the `anthropic-beta` header the endpoint requires for OAuth tokens.
    public static let oauthBeta = "oauth-2025-04-20"

    /// The headers to send with `token` — the only place its value is read.
    public static func headers(for token: OAuthAccessToken) -> [String: String] {
        [
            "Authorization": "Bearer \(token.value)",
            "anthropic-beta": oauthBeta,
        ]
    }
}
