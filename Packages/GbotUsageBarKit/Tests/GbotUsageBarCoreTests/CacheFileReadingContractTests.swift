import Foundation
import GbotUsageBarCore
import GbotUsageBarTestSupport
import Testing

/// The fake half of the `CacheFileReading` contract suite.
@Suite("CacheFileReading contract, against the fake")
struct CacheFileReadingContractTests {
    static let name = "file.blob"
    static let keptAnswers: [[String: Result<Data, UsageError>]] = [
        [name: .success(Data("{}".utf8))],
        [name: .failure(.cacheUnreadable)],
        [name: .failure(.cancelled)],
        [:],
    ]

    @Test(arguments: keptAnswers)
    func `the fake keeps the contract`(files: [String: Result<Data, UsageError>]) async {
        await CacheFileReadingContract.check(FakeCacheFileReader(files: files), fileName: Self.name)
    }

    @Test
    func `the contract asks more than once, for the file it is given`() async {
        let reader = FakeCacheFileReader(files: [:])
        await CacheFileReadingContract.check(reader, fileName: Self.name)
        #expect(reader.requestedFiles == [Self.name, Self.name])
    }

    @Test(arguments: [UsageError.noCachedUsage, .unexpectedFormat, .outOfDate])
    func `an error the reader must leave to Core is reported`(error: UsageError) async {
        let reader = FakeCacheFileReader(files: [Self.name: .failure(error)])
        #expect(await CacheFileReadingContract.violations(of: reader, fileName: Self.name)
            .count == 2)
    }
}
