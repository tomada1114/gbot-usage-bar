import ClaudeUsageBarCore
import ClaudeUsageBarTestSupport
import Testing

/// The fake half of the `OAuthTokenProviding` contract suite: the same function
/// `ClaudeUsageBarPlatformTests` runs against the real adapter under `just test-local`.
@Suite("OAuthTokenProviding contract, against the fake")
struct OAuthTokenProvidingContractTests {
    static let keptAnswers: [[Result<OAuthAccessToken, UsageError>]] = [
        [.success(OAuthAccessToken("token"))],
        [.failure(.notSignedIn)],
        [.failure(.credentialsUnreadable(status: 1))],
        [.failure(.credentialsUnreadable(status: nil))],
        [.failure(.cancelled)],
        [],
        [.success(OAuthAccessToken("token")), .failure(.notSignedIn)],
    ]

    @Test(arguments: keptAnswers)
    func `the fake keeps the contract`(answers: [Result<OAuthAccessToken, UsageError>]) async {
        await OAuthTokenProvidingContract.check(FakeOAuthTokenProvider(answering: answers))
    }

    @Test
    func `the contract asks more than once`() async {
        let provider = FakeOAuthTokenProvider(answering: [.success(OAuthAccessToken("token"))])
        await OAuthTokenProvidingContract.check(provider)
        #expect(provider.callCount == 2)
    }

    @Test
    func `a blank token is reported as a broken promise`() async {
        let provider = FakeOAuthTokenProvider(answering: [.success(OAuthAccessToken(" "))])
        #expect(await OAuthTokenProvidingContract.violations(of: provider).count == 2)
    }

    @Test(arguments: [UsageError.tokenExpired, .unreachable, .unexpectedResponse(statusCode: 500)])
    func `an error only a fetch may throw is reported`(error: UsageError) async {
        let provider = FakeOAuthTokenProvider(answering: [
            .success(OAuthAccessToken("token")),
            .failure(error),
        ])
        let violations = await OAuthTokenProvidingContract.violations(of: provider)
        #expect(violations.count == 1)
        #expect(violations.first?.hasPrefix("answer 2 of 2") == true)
    }
}
