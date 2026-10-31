import Foundation

/// The account-slot entry's JSON, every other field ignored.
private struct AccountSlotEntry: Decodable {
    let value: String?
}

/// The weekly-usage entry's JSON, every other field ignored. Every field is optional so a
/// missing one is a decision ``UsageCache`` makes, not a decoding error.
private struct CachedUsageEntry: Decodable {
    let value: CachedUsageValue?
}

private struct CachedUsageValue: Decodable {
    let kind: String?
    let reading: CachedUsageReading?
    let expiresAtMs: Double?
}

private struct CachedUsageReading: Decodable {
    let usage: CachedUsageFigures?
    let readAtMs: Double?
}

private struct CachedUsageFigures: Decodable {
    let percentUsed: Double?
    let nextResetMs: Double?
}

/// Reads the two cache entries the app needs, and decides what their JSON means.
///
/// Observed shapes (2026-10-31), every other field ignored:
/// - account slot: `{"schemaVersion":1,"value":"<provider>|user_…"}`
/// - weekly usage: `{"schemaVersion":2,"value":{"kind":"present","reading":{"usage":
///   {"percentUsed":2.77,"nextResetMs":…},"readAtMs":…},"expiresAtMs":…}}`
public enum UsageCache {
    private static let presentKind = "present"
    private static let millisecondsPerSecond = 1e3

    /// Reads the signed-in account's weekly usage through `reader`.
    public static func read(
        from reader: any CacheFileReading,
    ) async throws(UsageError) -> CachedUsage {
        let slotFile = CacheFileName.forKey(CacheFileName.accountSlotKey)
        guard let slotData = try await reader.contents(ofFile: slotFile) else {
            throw .noCachedUsage
        }
        let slot = try accountSlot(from: slotData)
        let usageFile = CacheFileName.forKey(CacheFileName.weeklyUsageKey(forSlot: slot))
        guard let usageData = try await reader.contents(ofFile: usageFile) else {
            throw .noCachedUsage
        }
        return try usage(from: usageData)
    }

    /// The account slot an account-slot entry names. A `null` or empty value means no
    /// account is signed in.
    package static func accountSlot(from data: Data) throws(UsageError) -> String {
        let entry: AccountSlotEntry = try decode(data)
        guard let slot = entry.value, !slot.isEmpty else {
            throw .noCachedUsage
        }
        return slot
    }

    /// The reading a weekly-usage entry holds. A kind other than `present` means the
    /// desktop app has no reading; a present one without a finite percent or a read time
    /// is a format this app does not know.
    package static func usage(from data: Data) throws(UsageError) -> CachedUsage {
        let entry: CachedUsageEntry = try decode(data)
        guard let value = entry.value else {
            throw .unexpectedFormat
        }
        guard value.kind == presentKind else {
            throw .noCachedUsage
        }
        guard
            let reading = value.reading,
            let percent = reading.usage?.percentUsed, percent.isFinite,
            let readAtMs = reading.readAtMs
        else {
            throw .unexpectedFormat
        }
        return CachedUsage(
            weekly: UsageWindow(
                utilization: percent,
                resetsAt: reading.usage?.nextResetMs.map(date),
            ),
            readAt: date(readAtMs),
            expiresAt: value.expiresAtMs.map(date),
        )
    }

    private static func decode<Entry: Decodable>(_ data: Data) throws(UsageError) -> Entry {
        do {
            return try JSONDecoder().decode(Entry.self, from: data)
        } catch {
            throw .unexpectedFormat
        }
    }

    private static func date(_ milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / millisecondsPerSecond)
    }
}
