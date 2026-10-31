import Foundation
import GbotUsageBarCore
import GbotUsageBarTestSupport
import Testing

/// What the desktop app's cache entries mean, and which files are read to find out.
@Suite("UsageCache")
struct UsageCacheTests {
    static let slot = "provider|user_1"
    static let slotFile = CacheFileName.forKey(CacheFileName.accountSlotKey)
    static let usageFile = CacheFileName.forKey(CacheFileName.weeklyUsageKey(forSlot: slot))
    static let slotJSON = Data(#"{"schemaVersion":1,"value":"provider|user_1"}"#.utf8)
    /// 9.64% used, resetting 2026-11-07T12:00:00Z, read 2026-11-07T08:30:00Z, expiring a
    /// day after that.
    static let usageJSON = Data(#"""
    {"schemaVersion":2,"value":{"kind":"present","selectedTeamId":null,"reading":{"usage":\#
    {"percentUsed":9.64,"nextResetMs":1794052800000,"isSandTrial":false},"readAtMs":1794040200000},\#
    "expiresAtMs":1794126600000}}
    """#.utf8)
    static let expected = CachedUsage(
        weekly: UsageWindow(
            utilization: 9.64,
            resetsAt: Date(timeIntervalSince1970: 1_794_052_800),
        ),
        readAt: Date(timeIntervalSince1970: 1_794_040_200),
        expiresAt: Date(timeIntervalSince1970: 1_794_126_600),
    )

    @Test
    func `the reading is found through the account slot`() async throws {
        let reader = FakeCacheFileReader(files: [
            Self.slotFile: .success(Self.slotJSON),
            Self.usageFile: .success(Self.usageJSON),
        ])
        #expect(try await UsageCache.read(from: reader) == Self.expected)
        #expect(reader.requestedFiles == [Self.slotFile, Self.usageFile])
    }

    @Test
    func `no account slot means no cached usage, and nothing else is read`() async {
        let reader = FakeCacheFileReader(files: [:])
        await #expect(throws: UsageError.noCachedUsage) {
            try await UsageCache.read(from: reader)
        }
        #expect(reader.requestedFiles == [Self.slotFile])
    }

    @Test
    func `a slot without its usage entry means no cached usage`() async {
        let reader = FakeCacheFileReader(files: [Self.slotFile: .success(Self.slotJSON)])
        await #expect(throws: UsageError.noCachedUsage) {
            try await UsageCache.read(from: reader)
        }
    }

    @Test(arguments: [UsageError.cacheUnreadable, .cancelled])
    func `a reader error is passed on`(error: UsageError) async {
        let reader = FakeCacheFileReader(files: [Self.slotFile: .failure(error)])
        await #expect(throws: error) {
            try await UsageCache.read(from: reader)
        }
    }

    @Test(arguments: [
        (#"{"value":null}"#, UsageError.noCachedUsage),
        (#"{"value":""}"#, .noCachedUsage),
        (#"{}"#, .noCachedUsage),
        (#"{"value":42}"#, .unexpectedFormat),
        ("not json", .unexpectedFormat),
    ])
    func `an account slot without a usable value is refused`(json: String, error: UsageError) {
        #expect(throws: error) {
            try UsageCache.accountSlot(from: Data(json.utf8))
        }
    }

    @Test
    func `the slot is read verbatim`() throws {
        #expect(try UsageCache.accountSlot(from: Self.slotJSON) == Self.slot)
    }

    @Test(arguments: [
        (#"{"value":{"kind":"absent"}}"#, UsageError.noCachedUsage),
        (#"{"value":{}}"#, .noCachedUsage),
        (#"{"schemaVersion":2}"#, .unexpectedFormat),
        (#"{"value":{"kind":"present"}}"#, .unexpectedFormat),
        (#"{"value":{"kind":"present","reading":{"usage":{},"readAtMs":1}}}"#, .unexpectedFormat),
        (#"{"value":{"kind":"present","reading":{"usage":{"percentUsed":5}}}}"#, .unexpectedFormat),
        (
            #"{"value":{"kind":"present","reading":{"usage":{"percentUsed":"5"},"readAtMs":1}}}"#,
            .unexpectedFormat,
        ),
        ("", .unexpectedFormat),
    ])
    func `a usage entry without a reading is refused`(json: String, error: UsageError) {
        #expect(throws: error) {
            try UsageCache.usage(from: Data(json.utf8))
        }
    }

    @Test
    func `a reading without a reset or an expiry leaves them unknown`() throws {
        let json = #"{"value":{"kind":"present","reading":"#
            + #"{"usage":{"percentUsed":0,"nextResetMs":null},"readAtMs":0}}}"#
        let cached = try UsageCache.usage(from: Data(json.utf8))
        #expect(cached == CachedUsage(
            weekly: UsageWindow(utilization: 0, resetsAt: nil),
            readAt: Date(timeIntervalSince1970: 0),
            expiresAt: nil,
        ))
    }
}
