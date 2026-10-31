import Foundation
import GbotUsageBarCore
import Testing

/// How a cache entry's key becomes the file it is stored in.
@Suite("CacheFileName")
struct CacheFileNameTests {
    /// RFC 4648 §10's base32 test vectors, lowercased and with the padding dropped, plus
    /// a two-byte input worked out by hand (`ab` is 01100 00101 10001 0[0000]).
    @Test(arguments: [
        ("ab", "mfra"),
        ("", ""),
        ("f", "my"),
        ("foo", "mzxw6"),
        ("foob", "mzxw6yq"),
        ("fooba", "mzxw6ytb"),
        ("foobar", "mzxw6ytboi"),
    ])
    func `base32 matches RFC 4648 without padding`(input: String, expected: String) {
        #expect(CacheFileName.base32(Data(input.utf8)) == expected)
    }

    @Test(arguments: [
        ("abcXYZ019", "abcXYZ019"),
        ("-_.!~*'()", "-_.!~*'()"),
        ("provider|user_1", "provider%7Cuser_1"),
        ("a b/c?d", "a%20b%2Fc%3Fd"),
        ("é", "%C3%A9"),
    ])
    func `the slot is percent-encoded like encodeURIComponent`(input: String, expected: String) {
        #expect(CacheFileName.uriComponent(input) == expected)
    }

    @Test
    func `the account slot entry has the file name observed on disk`() {
        #expect(CacheFileName.forKey(CacheFileName.accountSlotKey)
            == "onqw4zbomnwgszlooqxhg3djmnss4y3mnfsw45bnnvsxiyjomfrwg33vnz2c243mn52a.blob")
    }

    @Test
    func `the weekly usage key carries the encoded slot`() {
        #expect(CacheFileName.weeklyUsageKey(forSlot: "provider|user_1")
            == "sand.client.slice.account.provider%7Cuser_1.weekly-usage.cache")
    }
}
