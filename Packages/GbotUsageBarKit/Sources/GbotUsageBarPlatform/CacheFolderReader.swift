import Foundation
import GbotUsageBarCore

/// Reads files from the desktop app's cache folder, read-only.
///
/// Translation only: a missing file is `nil`, any other read failure is
/// ``UsageError/cacheUnreadable``. It never creates, writes, or removes anything there.
public struct CacheFolderReader: CacheFileReading {
    /// Where the desktop app keeps its cache, under the user's Application Support.
    public static let defaultFolder = URL.applicationSupportDirectory
        .appending(path: "Grok Bot/sand-client-persistence", directoryHint: .isDirectory)

    private let folder: URL

    public init(folder: URL = Self.defaultFolder) {
        self.folder = folder
    }

    public func contents(ofFile fileName: String) throws(UsageError) -> Data? {
        let file = folder.appending(path: fileName, directoryHint: .notDirectory)
        do {
            try Task.checkCancellation()
            return try Data(contentsOf: file)
        } catch is CancellationError {
            throw .cancelled
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            throw .cacheUnreadable
        }
    }
}
