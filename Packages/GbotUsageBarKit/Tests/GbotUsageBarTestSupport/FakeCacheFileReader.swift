import Foundation
import GbotUsageBarCore
import os

/// The one fake of ``GbotUsageBarCore/CacheFileReading``, shared by every test target.
///
/// Answers from the files a test hands it, keyed by file name, and records each name it
/// was asked for. `CacheFileReadingContract` holds it to the same promises as the real
/// adapter.
package final class FakeCacheFileReader: CacheFileReading {
    /// The file names asked for so far, in order.
    package var requestedFiles: [String] {
        requested.withLock { $0 }
    }

    private let files: [String: Result<Data, UsageError>]
    private let requested = OSAllocatedUnfairLock(initialState: [String]())

    /// Answers each name in `files` with its result, and any other name with `nil` (no
    /// such file).
    package init(files: [String: Result<Data, UsageError>]) {
        self.files = files
    }

    package func contents(ofFile fileName: String) throws(UsageError) -> Data? {
        requested.withLock { $0.append(fileName) }
        return try files[fileName]?.get()
    }
}
