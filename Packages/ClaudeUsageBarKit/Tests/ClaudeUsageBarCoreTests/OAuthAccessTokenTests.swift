import ClaudeUsageBarCore
import Testing

/// The token wrapper's one job: never showing its value by accident.
@Suite("OAuthAccessToken")
struct OAuthAccessTokenTests {
    @Test
    func `never shows its value when described or reflected`() {
        let token = OAuthAccessToken("sk-secret-value")
        #expect(!String(describing: token).contains("sk-secret-value"))
        #expect(!String(reflecting: token).contains("sk-secret-value"))
        #expect(!"\(token)".contains("sk-secret-value"))
        var dumped = ""
        dump(token, to: &dumped)
        #expect(!dumped.contains("sk-secret-value"))
    }

    @Test
    func `keeps the value for the one place that sends it`() {
        #expect(OAuthAccessToken("abc").value == "abc")
        #expect(OAuthAccessToken("abc") != OAuthAccessToken("xyz"))
    }
}
