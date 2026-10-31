import Foundation
import GbotUsageBarCore
import Testing

/// The promises ``GbotUsageBarCore/CacheFileReading`` makes, checked against any
/// implementation of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// `GbotUsageBarCoreTests` runs ``check(_:fileName:)`` against ``FakeCacheFileReader`` on
/// every `just test`; `GbotUsageBarPlatformTests` runs it against `CacheFolderReader` under
/// `.requiresLocalMachine` (`just test-local`). Every clause is one the port's `///`
/// states; a new clause is stated there first.
package enum CacheFileReadingContract {
    /// How many times ``violations(of:fileName:)`` asks: the cache is read afresh on every
    /// refresh, so a promise kept only by the first answer is not kept.
    static let askCount = 2

    /// A description of every broken promise, empty when `reader` keeps them all.
    package static func violations(
        of reader: some CacheFileReading,
        fileName: String,
    ) async -> [String] {
        var broken: [String] = []
        for ask in 1 ... askCount {
            do throws(UsageError) {
                _ = try await reader.contents(ofFile: fileName)
            } catch {
                switch error {
                case .cancelled, .cacheUnreadable:
                    break

                case .noCachedUsage, .unexpectedFormat, .outOfDate:
                    broken.append("answer \(ask) of \(askCount) throws \(error)")
                }
            }
        }
        return broken
    }

    /// Records an issue for every promise `reader` breaks.
    package static func check(_ reader: some CacheFileReading, fileName: String) async {
        let broken = await violations(of: reader, fileName: fileName)
        #expect(
            broken.isEmpty,
            "\(type(of: reader)) breaks the CacheFileReading contract: \(broken)",
        )
    }
}
