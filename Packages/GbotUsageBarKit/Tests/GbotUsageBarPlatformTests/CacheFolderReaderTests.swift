import Foundation
import GbotUsageBarCore
import GbotUsageBarPlatform
import GbotUsageBarTestSupport
import Testing

/// `CacheFolderReader` against the real file system, and against the desktop app's real
/// cache when this Mac has one.
@Suite("CacheFolderReader against the real file system", .requiresLocalMachine)
struct CacheFolderReaderTests {
    static func withFolder(_ body: (URL) async throws -> Void) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "GbotUsageBarTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try await body(folder)
    }

    @Test
    func `a file's bytes are read, and a missing file or folder is nil`() async throws {
        try await Self.withFolder { folder in
            try Data("{}".utf8).write(to: folder.appending(path: "a.blob"))
            let reader = CacheFolderReader(folder: folder)
            #expect(try reader.contents(ofFile: "a.blob") == Data("{}".utf8))
            #expect(try reader.contents(ofFile: "missing.blob") == nil)
            let absent = CacheFolderReader(folder: folder.appending(path: "absent"))
            #expect(try absent.contents(ofFile: "a.blob") == nil)
        }
    }

    @Test
    func `a file that cannot be read is cacheUnreadable`() async throws {
        try await Self.withFolder { folder in
            let file = folder.appending(path: "locked.blob")
            try Data("{}".utf8).write(to: file)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o000],
                ofItemAtPath: file.path,
            )
            defer { try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: file.path,
            ) }
            #expect(throws: UsageError.cacheUnreadable) {
                try CacheFolderReader(folder: folder).contents(ofFile: "locked.blob")
            }
        }
    }

    @Test
    func `keeps the CacheFileReading contract the fake is held to`() async throws {
        try await Self.withFolder { folder in
            try Data("{}".utf8).write(to: folder.appending(path: "a.blob"))
            let reader = CacheFolderReader(folder: folder)
            await CacheFileReadingContract.check(reader, fileName: "a.blob")
            await CacheFileReadingContract.check(reader, fileName: "missing.blob")
        }
    }

    /// Needs the desktop app installed, signed in, and run at least once on this Mac.
    @Test
    func `the desktop app's real cache yields a weekly reading`() async throws {
        let cached = try await UsageCache.read(from: CacheFolderReader())
        #expect(cached.weekly.utilization >= 0)
        #expect(cached.weekly.resetsAt != nil)
    }
}
