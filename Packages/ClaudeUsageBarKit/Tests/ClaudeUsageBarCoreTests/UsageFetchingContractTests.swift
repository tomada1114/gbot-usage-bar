import ClaudeUsageBarCore
import ClaudeUsageBarTestSupport
import Foundation
import Testing

/// The fake half of the `UsageFetching` contract suite.
@Suite("UsageFetching contract, against the fake")
struct UsageFetchingContractTests {
    static let token = OAuthAccessToken("token")
    static let keptAnswers: [[Result<UsageResponse, UsageError>]] = [
        [.success(UsageResponse(statusCode: 200, body: Data()))],
        [.success(UsageResponse(statusCode: 401, body: Data()))],
        [.success(UsageResponse(statusCode: 599, body: Data()))],
        [.failure(.unreachable)],
        [.failure(.unexpectedResponse(statusCode: nil))],
        [.failure(.cancelled)],
        [],
    ]

    @Test(arguments: keptAnswers)
    func `the fake keeps the contract`(answers: [Result<UsageResponse, UsageError>]) async {
        await UsageFetchingContract.check(FakeUsageFetcher(answering: answers), with: Self.token)
    }

    @Test
    func `the contract asks more than once, with the token it is given`() async {
        let fetcher = FakeUsageFetcher(answering: [])
        await UsageFetchingContract.check(fetcher, with: Self.token)
        #expect(fetcher.receivedTokens == [Self.token, Self.token])
    }

    @Test(arguments: [99, 600])
    func `a status no HTTP answer carries is reported`(status: Int) async {
        let response = UsageResponse(statusCode: status, body: Data())
        let fetcher = FakeUsageFetcher(answering: [.success(response)])
        #expect(await UsageFetchingContract.violations(of: fetcher, with: Self.token).count == 2)
    }

    @Test(arguments: [
        UsageError.tokenExpired,
        .notSignedIn,
        .credentialsUnreadable(status: 1),
        .unexpectedResponse(statusCode: 500),
    ])
    func `an error the fetch must leave to Core is reported`(error: UsageError) async {
        let fetcher = FakeUsageFetcher(answering: [.failure(error)])
        #expect(await UsageFetchingContract.violations(of: fetcher, with: Self.token).count == 2)
    }
}
