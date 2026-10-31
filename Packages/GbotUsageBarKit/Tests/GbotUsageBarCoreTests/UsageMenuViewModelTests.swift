import Foundation
import GbotUsageBarCore
import GbotUsageBarTestSupport
import os
import Testing

/// A reader that answers each refresh from the next fake in turn, repeating the last, so
/// a test can change what the cache holds between refreshes.
final class SequencedReader: CacheFileReading {
    private let answers: [FakeCacheFileReader]
    private let slotFile = CacheFileName.forKey(CacheFileName.accountSlotKey)
    private let refreshes = OSAllocatedUnfairLock(initialState: -1)

    init(answers: [FakeCacheFileReader]) {
        self.answers = answers
    }

    func contents(ofFile fileName: String) throws(UsageError) -> Data? {
        let index = refreshes.withLock { count in
            if fileName == slotFile {
                count += 1
            }
            return min(max(count, 0), answers.count - 1)
        }
        return try answers[index].contents(ofFile: fileName)
    }
}

/// What a refresh does to the menu's state, and how the polling loop paces refreshes.
/// The wording that state renders as is `UsagePresentationTests`'.
@MainActor
@Suite("UsageMenuViewModel")
struct UsageMenuViewModelTests {
    struct Harness {
        let reader: FakeCacheFileReader
        let terminator = FakeApplicationTerminator()

        var ports: UsageMenuViewModel.Ports {
            UsageMenuViewModel.Ports(cacheReader: reader, terminator: terminator)
        }

        /// How many times the account slot — the first file of every refresh — was read.
        var refreshCount: Int {
            let accountSlotFile = CacheFileName.forKey(CacheFileName.accountSlotKey)
            return reader.requestedFiles.count { $0 == accountSlotFile }
        }
    }

    /// 2026-11-07T09:00:00Z: after the reading below, before its reset and its expiry.
    static let fixedNow = Date(timeIntervalSince1970: 1_794_042_000)
    /// 2026-11-07T08:30:00Z.
    static let readAt = Date(timeIntervalSince1970: 1_794_040_200)
    static let slotFile = CacheFileName.forKey(CacheFileName.accountSlotKey)
    static let usageFile = CacheFileName.forKey(CacheFileName.weeklyUsageKey(forSlot: "p|u"))
    static let slotJSON = Data(#"{"value":"p|u"}"#.utf8)
    /// 76% used, resetting 2026-11-07T12:00:00Z, read at ``readAt``, expiring a day later.
    static let usageJSON = Data(#"""
    {"value":{"kind":"present","reading":{"usage":{"percentUsed":76,"nextResetMs":1794052800000},\#
    "readAtMs":1794040200000},"expiresAtMs":1794126600000}}
    """#.utf8)
    static let weekly = UsageWindow(
        utilization: 76,
        resetsAt: Date(timeIntervalSince1970: 1_794_052_800),
    )
    static let good = UsageState(weekly: weekly, failure: nil, lastUpdated: readAt)

    static func harness() -> Harness {
        harness(usage: .success(usageJSON))
    }

    static func harness(usage: Result<Data, UsageError>?) -> Harness {
        var files: [String: Result<Data, UsageError>] = [slotFile: .success(slotJSON)]
        files[usageFile] = usage
        return Harness(reader: FakeCacheFileReader(files: files))
    }

    static func harness(slot: Result<Data, UsageError>) -> Harness {
        Harness(reader: FakeCacheFileReader(files: [
            slotFile: slot,
            usageFile: .success(usageJSON),
        ]))
    }

    static func model(
        _ harness: Harness,
        clock: any Clock<Duration>,
        tuning: Tuning,
        now: Date,
    ) -> UsageMenuViewModel {
        UsageMenuViewModel(ports: harness.ports, clock: clock, now: { now }, tuning: tuning)
    }

    static func model(_ harness: Harness) -> UsageMenuViewModel {
        model(harness, clock: ContinuousClock(), tuning: .default, now: fixedNow)
    }

    static func model(_ harness: Harness, now: Date) -> UsageMenuViewModel {
        model(harness, clock: ContinuousClock(), tuning: .default, now: now)
    }

    static func model(_ harness: Harness, clock: any Clock<Duration>) -> UsageMenuViewModel {
        model(harness, clock: clock, tuning: .default, now: fixedNow)
    }

    static func model(_ harness: Harness, tuning: Tuning) -> UsageMenuViewModel {
        model(harness, clock: ContinuousClock(), tuning: tuning, now: fixedNow)
    }

    static func model(reader: SequencedReader) -> UsageMenuViewModel {
        let fixed = fixedNow
        return UsageMenuViewModel(
            ports: UsageMenuViewModel.Ports(
                cacheReader: reader,
                terminator: FakeApplicationTerminator(),
            ),
        ) { fixed }
    }

    // MARK: - Refresh

    @Test
    func `construction asks no port`() {
        let harness = Self.harness()
        let model = Self.model(harness)
        #expect(model.state == UsageState())
        #expect(harness.reader.requestedFiles.isEmpty)
    }

    @Test
    func `a good read publishes the numbers and when the desktop app read them`() async {
        let model = Self.model(Self.harness())
        await model.refresh()
        #expect(model.state == Self.good)
    }

    @Test(arguments: [UsageError.noCachedUsage, .cacheUnreadable, .unexpectedFormat])
    func `a read failure is published`(error: UsageError) async {
        let model = Self.model(Self.harness(usage: .failure(error)))
        await model.refresh()
        #expect(model.state == UsageState(weekly: nil, failure: error, lastUpdated: nil))
    }

    @Test
    func `a missing usage entry is no cached usage`() async {
        let model = Self.model(Self.harness(usage: nil))
        await model.refresh()
        #expect(model.state.failure == .noCachedUsage)
    }

    @Test
    func `an expired reading keeps its numbers, flagged out of date`() async {
        // Expires 2026-11-07T09:50:00Z, before its reset; read at that moment exactly.
        let expiring = Data(#"""
        {"value":{"kind":"present","reading":{"usage":{"percentUsed":76,"nextResetMs":1794052800000},\#
        "readAtMs":1794040200000},"expiresAtMs":1794045000000}}
        """#.utf8)
        let model = Self.model(
            Self.harness(usage: .success(expiring)),
            now: Date(timeIntervalSince1970: 1_794_045_000),
        )
        await model.refresh()
        #expect(model.state == UsageState(
            weekly: Self.weekly,
            failure: .outOfDate,
            lastUpdated: Self.readAt,
        ))
    }

    @Test
    func `a reading from before the weekly reset loses its numbers`() async {
        // 2026-11-07T12:00:00Z, the reset exactly.
        let model = Self.model(Self.harness(), now: Date(timeIntervalSince1970: 1_794_052_800))
        await model.refresh()
        #expect(model.state == UsageState(
            weekly: nil,
            failure: .outOfDate,
            lastUpdated: Self.readAt,
        ))
    }

    @Test
    func `a reading a second before its reset and expiry is current`() async {
        let model = Self.model(Self.harness(), now: Date(timeIntervalSince1970: 1_794_052_799))
        await model.refresh()
        #expect(model.state == Self.good)
    }

    @Test
    func `a failure after a success keeps the last good numbers and their time`() async {
        let reader = SequencedReader(answers: [
            Self.harness().reader,
            Self.harness(usage: .failure(.cacheUnreadable)).reader,
        ])
        let model = Self.model(reader: reader)
        await model.refresh()
        await model.refresh()
        #expect(model.state == UsageState(
            weekly: Self.weekly,
            failure: .cacheUnreadable,
            lastUpdated: Self.readAt,
        ))
    }

    @Test
    func `a success after a failure clears the failure`() async {
        let reader = SequencedReader(answers: [
            Self.harness(usage: .failure(.unexpectedFormat)).reader,
            Self.harness().reader,
        ])
        let model = Self.model(reader: reader)
        await model.refresh()
        #expect(model.state.failure == .unexpectedFormat)
        await model.refresh()
        #expect(model.state == Self.good)
    }

    @Test
    func `a cancelled refresh changes nothing`() async {
        let reader = SequencedReader(answers: [
            Self.harness().reader,
            Self.harness(usage: .failure(.cancelled)).reader,
        ])
        let model = Self.model(reader: reader)
        await model.refresh()
        await model.refresh()
        #expect(model.state == Self.good)
    }

    @Test
    func `a cancelled slot read changes nothing either`() async {
        let model = Self.model(Self.harness(slot: .failure(.cancelled)))
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
        #expect(harness.refreshCount == 3)
        #expect(clock.sleeps == [.seconds(60), .seconds(60), .seconds(60)])
    }

    @Test
    func `run paces itself by the tuning it was given`() async {
        let clock = StepClock(sleepsBeforeStopping: 0)
        let tuning = Tuning(refreshInterval: .seconds(5))
        let model = Self.model(Self.harness(), clock: clock, tuning: tuning, now: Self.fixedNow)
        await model.run()
        #expect(clock.sleeps == [.seconds(5)])
    }

    @Test
    func `run keeps polling after a failed refresh`() async {
        let harness = Self.harness(slot: .failure(.cacheUnreadable))
        let model = Self.model(harness, clock: StepClock(sleepsBeforeStopping: 1))
        await model.run()
        #expect(harness.refreshCount == 2)
    }

    @Test
    func `starting to poll twice runs one loop`() async {
        let harness = Self.harness()
        let model = Self.model(harness, clock: StepClock(sleepsBeforeStopping: 1))
        let first = model.startPolling()
        let second = model.startPolling()
        #expect(first == second)
        await first.value
        #expect(harness.refreshCount == 2)
    }

    @Test
    func `stopping ends the loop, and polling can start again afterwards`() async {
        let tuning = Tuning(refreshInterval: .seconds(100_000))
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
}
