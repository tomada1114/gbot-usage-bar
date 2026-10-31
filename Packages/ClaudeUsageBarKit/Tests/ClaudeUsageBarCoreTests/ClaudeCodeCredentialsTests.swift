import ClaudeUsageBarCore
import Foundation
import Testing

/// Reading the access token out of the JSON Claude Code keeps in its keychain item.
@Suite("ClaudeCodeCredentials")
struct ClaudeCodeCredentialsTests {
    @Test
    func `reads claudeAiOauth accessToken and ignores the other keys`() throws {
        let payload = Data("""
        {"claudeAiOauth":{"accessToken":"sk-test-access","refreshToken":"sk-test-refresh",
        "expiresAt":1790000000000,"scopes":["user:inference"]},"mcpOAuth":{}}
        """.utf8)
        let token = try ClaudeCodeCredentials.accessToken(from: payload)
        #expect(token == OAuthAccessToken("sk-test-access"))
    }

    @Test
    func `trailing whitespace from the security command is tolerated`() throws {
        let payload = Data((#"{"claudeAiOauth":{"accessToken":"abc"}}"# + "\n").utf8)
        #expect(try ClaudeCodeCredentials.accessToken(from: payload).value == "abc")
    }

    @Test(arguments: [
        "",
        "not json",
        "[]",
        "{}",
        #"{"claudeAiOauth":null}"#,
        #"{"claudeAiOauth":{}}"#,
        #"{"claudeAiOauth":{"accessToken":null}}"#,
        #"{"claudeAiOauth":{"accessToken":42}}"#,
        #"{"claudeAiOauth":{"accessToken":""}}"#,
        #"{"claudeAiOauth":{"accessToken":"   "}}"#,
    ])
    func `a payload without a usable token means not signed in`(payload: String) {
        #expect(throws: UsageError.notSignedIn) {
            try ClaudeCodeCredentials.accessToken(from: Data(payload.utf8))
        }
    }
}
