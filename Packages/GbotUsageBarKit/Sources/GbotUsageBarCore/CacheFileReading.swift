import Foundation

/// A port: "what bytes does this file in the desktop app's cache folder hold?"
///
/// `GbotUsageBarPlatform`'s `CacheFolderReader` reads the folder on disk; tests substitute
/// `FakeCacheFileReader`. The adapter only carries bytes across: which file to ask for
/// and what its bytes mean is ``UsageCache``'s decision, in Core. Nothing behind this port
/// ever writes to, creates, or removes anything in that folder.
public protocol CacheFileReading: Sendable {
    /// The whole contents of `fileName` in the cache folder, or `nil` when the folder or
    /// the file does not exist.
    ///
    /// The only errors are ``UsageError/cacheUnreadable`` — the file exists but could not
    /// be read — and ``UsageError/cancelled``. `CacheFileReadingContract` in
    /// `GbotUsageBarTestSupport` checks these clauses against the fake (`just test`) and the
    /// real adapter (`just test-local`); a new clause is stated here first, then added there.
    func contents(ofFile fileName: String) async throws(UsageError) -> Data?
}
