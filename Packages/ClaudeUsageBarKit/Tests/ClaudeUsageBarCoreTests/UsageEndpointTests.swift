import ClaudeUsageBarCore
import Foundation
import Testing

/// The request the usage adapter sends; spelled in Core so a test pins it.
@Suite("UsageEndpoint")
struct UsageEndpointTests {
    @Test
    func `asks the OAuth usage endpoint on api anthropic com`() {
        #expect(UsageEndpoint.url.absoluteString == "https://api.anthropic.com/api/oauth/usage")
    }

    @Test
    func `sends the bearer token and the OAuth beta header`() {
        let headers = UsageEndpoint.headers(for: OAuthAccessToken("tok"))
        #expect(headers == [
            "Authorization": "Bearer tok",
            "anthropic-beta": "oauth-2025-04-20",
        ])
    }
}
