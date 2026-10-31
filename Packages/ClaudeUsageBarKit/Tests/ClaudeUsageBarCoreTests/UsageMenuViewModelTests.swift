import ClaudeUsageBarCore
import ClaudeUsageBarTestSupport
import Foundation
import Testing

/// What a refresh does to the menu's state, and how the polling loop paces refreshes.
/// The wording that state renders as is `UsagePresentationTests`'.
@MainActor
@Suite("UsageMenuViewModel")
struct UsageMenuViewModelTests {
    struct Harness {
        let tokens: FakeOAuthTokenProvider
        let fetcher: FakeUsageFetcher
        let terminator = FakeApplicationTerminator()

        var ports: UsageMenuViewModel.Ports {
            UsageMenuViewModel.Ports(
                tokenProvider: tokens,
                usageFetcher: fetcher,
                terminator: terminator,
            )
        }
    }

    static let token = OAuthAccessToken("token")
    static let fixedNow = Date(timeIntervalSince1970: 1_790_769_600)
    static let body = Data(#"{"seven_day":{"utilization":76},"five_hour":{"utilization":19}}"#.utf8)
    static let snapshot = UsageSnapshot(
        fiveHour: UsageWindow(utilization: 19, resetsAt: nil),
        sevenDay: UsageWindow(utilization: 76, resetsAt: nil),
    )

    static let okTokens: [Result<OAuthAccessToken, UsageError>] = [.success(token)]
    static let okResponses: [Result<UsageResponse, UsageError>] = [
        .success(UsageResponse(statusCode: 200, body: body)),
    ]

    static func harness(
        tokens: [Result<OAuthAccessToken, UsageError>],
        responses: [Result<UsageResponse, UsageError>],
    ) -> Harness {
        Harness(
            tokens: FakeOAuthTokenProvider(answering: tokens),
            fetcher: FakeUsageFetcher(answering: responses),
        )
    }

    static func harness() -> Harness {
        harness(tokens: okTokens, responses: okResponses)
    }

    static func harness(tokens: [Result<OAuthAccessToken, UsageError>]) -> Harness {
        harness(tokens: tokens, responses: okResponses)
    }

    static func harness(responses: [Result<UsageResponse, UsageError>]) -> Harness {
        harness(tokens: okTokens, responses: responses)
    }

    static func model(
        _ harness: Harness,
        clock: any Clock<Duration>,
        tuning: Tuning,
    ) -> UsageMenuViewModel {
        let fixed = fixedNow
        return UsageMenuViewModel(
            ports: harness.ports,
            clock: clock,
            now: { fixed },
            tuning: tuning,
        )
    }

    static func model(_ harness: Harness) -> UsageMenuViewModel {
        model(harness, clock: ContinuousClock(), tuning: .default)
    }

    static func model(_ harness: Harness, clock: any Clock<Duration>) -> UsageMenuViewModel {
        model(harness, clock: clock, tuning: .default)
    }

    static func model(_ harness: Harness, tuning: Tuning) -> UsageMenuViewModel {
        model(harness, clock: ContinuousClock(), tuning: tuning)
    }

    // MARK: - Refresh

    @Test
    func `construction asks no port`() {
        let harness = Self.harness()
        let model = Self.model(harness)
        #expect(model.state == UsageState())
        #expect(harness.tokens.callCount == 0)
        #expect(harness.fetcher.callCount == 0)
    }

    @Test
    func `a successful refresh publishes the snapshot and when it arrived`() async {
        let harness = Self.harness()
        let model = Self.model(harness)
        await model.refresh()
        #expect(model.state == UsageState(
            snapshot: Self.snapshot,
            failure: nil,
            lastUpdated: Self.fixedNow,
        ))
        #expect(harness.fetcher.receivedTokens == [Self.token])
    }

    @Test(arguments: [UsageError.notSignedIn, .credentialsUnreadable(status: 36)])
    func `a token failure is published and no request is sent`(error: UsageError) async {
        let harness = Self.harness(tokens: [.failure(error)])
        let model = Self.model(harness)
        await model.refresh()
        #expect(model.state == UsageState(snapshot: nil, failure: error, lastUpdated: nil))
        #expect(harness.fetcher.callCount == 0)
    }

    @Test(arguments: [
        (Result<UsageResponse, UsageError>.failure(.unreachable), UsageError.unreachable),
        (.success(UsageResponse(statusCode: 401, body: Data())), .tokenExpired),
        (
            .success(UsageResponse(statusCode: 500, body: Data())),
            .unexpectedResponse(statusCode: 500),
        ),
        (
            .success(UsageResponse(statusCode: 200, body: Data("oops".utf8))),
            .unexpectedResponse(statusCode: 200),
        ),
    ])
    func `a fetch failure is published`(
        answer: Result<UsageResponse, UsageError>,
        expected: UsageError,
    ) async {
        let model = Self.model(Self.harness(responses: [answer]))
        await model.refresh()
        #expect(model.state.failure == expected)
        #expect(model.state.snapshot == nil)
    }

    @Test
    func `a failure after a success keeps the last good numbers and their time`() async {
        let model = Self.model(Self.harness(responses: [
            .success(UsageResponse(statusCode: 200, body: Self.body)),
            .failure(.unreachable),
        ]))
        await model.refresh()
        await model.refresh()
        #expect(model.state == UsageState(
            snapshot: Self.snapshot,
            failure: .unreachable,
            lastUpdated: Self.fixedNow,
        ))
    }

    @Test
    func `a success after a failure clears the failure`() async {
        let model = Self.model(Self.harness(responses: [
            .failure(.unreachable),
            .success(UsageResponse(statusCode: 200, body: Self.body)),
        ]))
        await model.refresh()
        #expect(model.state.failure == .unreachable)
        await model.refresh()
        #expect(model.state == UsageState(
            snapshot: Self.snapshot,
            failure: nil,
            lastUpdated: Self.fixedNow,
        ))
    }

    @Test
    func `a cancelled refresh changes nothing`() async {
        let harness = Self.harness(responses: [
            .success(UsageResponse(statusCode: 200, body: Self.body)),
            .failure(.cancelled),
        ])
        let model = Self.model(harness)
        await model.refresh()
        let before = model.state
        await model.refresh()
        #expect(model.state == before)
        #expect(harness.fetcher.callCount == 2)
    }

    @Test
    func `a cancelled token read changes nothing either`() async {
        let model = Self.model(Self.harness(tokens: [.failure(.cancelled)]))
        await model.refresh()
        #expect(model.state == UsageState())
    }

    // MARK: - Polling

    @Test
    func `run refreshes, then sleeps the refresh interval, until the sleep is cancelled`() async {
        let harness = Self.harness()
        let clock = StepClock(sleepsBeforeStopping: 2)
        let model = Self.model(harness, clock: clock)
        await model.run()
        #expect(harness.fetcher.callCount == 3)
        #expect(clock.sleeps == [.seconds(60), .seconds(60), .seconds(60)])
    }

    @Test
    func `run paces itself by the tuning it was given`() async {
        let clock = StepClock(sleepsBeforeStopping: 0)
        let tuning = Tuning(refreshInterval: .seconds(5), requestTimeout: .seconds(1))
        let model = Self.model(Self.harness(), clock: clock, tuning: tuning)
        await model.run()
        #expect(clock.sleeps == [.seconds(5)])
    }

    @Test
    func `run keeps polling after a failed refresh`() async {
        let harness = Self.harness(tokens: [.failure(.notSignedIn)])
        let model = Self.model(harness, clock: StepClock(sleepsBeforeStopping: 1))
        await model.run()
        #expect(harness.tokens.callCount == 2)
    }

    @Test
    func `starting to poll twice runs one loop`() async {
        let harness = Self.harness()
        let model = Self.model(harness, clock: StepClock(sleepsBeforeStopping: 1))
        let first = model.startPolling()
        let second = model.startPolling()
        #expect(first == second)
        await first.value
        #expect(harness.fetcher.callCount == 2)
    }

    @Test
    func `stopping ends the loop, and polling can start again afterwards`() async {
        let tuning = Tuning(refreshInterval: .seconds(100_000), requestTimeout: .seconds(1))
        let model = Self.model(Self.harness(), tuning: tuning)
        let first = model.startPolling()
        model.stopPolling()
        await first.value
        #expect(first.isCancelled)
        let second = model.startPolling()
        #expect(second != first)
        model.stopPolling()
        await second.value
    }

    @Test
    func `stopping when nothing polls does nothing`() {
        let model = Self.model(Self.harness())
        model.stopPolling()
        #expect(model.state == UsageState())
    }

    // MARK: - Quit

    @Test
    func `quit asks the terminator once`() {
        let harness = Self.harness()
        Self.model(harness).quit()
        #expect(harness.terminator.terminateCount == 1)
    }

    @Test
    func `the presentation renders the current state`() async {
        let model = Self.model(Self.harness())
        #expect(model.presentation.badgeText == "--")
        await model.refresh()
        #expect(model.presentation.badgeText == "76")
    }

    // MARK: - Badge window

    @Test
    func `the badge shows the weekly window until another is chosen`() async {
        let model = Self.model(Self.harness())
        #expect(model.badgeWindow == .weekly)
        await model.refresh()
        model.showInMenuBar(.fiveHour)
        #expect(model.badgeWindow == .fiveHour)
        #expect(model.presentation.badgeText == "19")
        model.showInMenuBar(.weekly)
        #expect(model.presentation.badgeText == "76")
    }
}
