import Foundation

/// How the desktop app names the files in its cache folder: each entry's key, encoded as
/// lowercase RFC 4648 base32 without `=` padding, plus `.blob`.
///
/// Observed on the owner's Mac (2026-10-31), not documented: the key
/// `sand.client.slice.ui-layout` is stored as
/// `onqw4zbomnwgszlooqxhg3djmnss45ljfvwgc6lpov2a.blob`.
public enum CacheFileName {
    /// The key of the entry naming the signed-in account's slot.
    public static let accountSlotKey = "sand.client.slice.client-meta.account-slot"

    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
    private static let bitsPerByte = 8
    private static let bitsPerCharacter = 5
    private static let characterMask = 0b11111

    /// The key of the weekly-usage entry for `slot`, which the key carries
    /// percent-encoded the way JavaScript's `encodeURIComponent` does (`|` as `%7C`).
    public static func weeklyUsageKey(forSlot slot: String) -> String {
        "sand.client.slice.account.\(uriComponent(slot)).weekly-usage.cache"
    }

    /// The file name an entry with `key` is stored under.
    public static func forKey(_ key: String) -> String {
        base32(Data(key.utf8)) + ".blob"
    }

    /// `data` in lowercase base32, with no padding.
    package static func base32(_ data: Data) -> String {
        var output = ""
        var buffer = 0
        var bitCount = 0
        for byte in data {
            buffer = (buffer << bitsPerByte) | Int(byte)
            bitCount += bitsPerByte
            while bitCount >= bitsPerCharacter {
                bitCount -= bitsPerCharacter
                output.append(alphabet[(buffer >> bitCount) & characterMask])
            }
            buffer &= (1 << bitCount) - 1
        }
        if bitCount > 0 {
            output.append(alphabet[(buffer << (bitsPerCharacter - bitCount)) & characterMask])
        }
        return output
    }

    /// `text` with everything but `encodeURIComponent`'s unreserved characters
    /// (`A–Z a–z 0–9 - _ . ! ~ * ' ( )`) percent-encoded as UTF-8, in uppercase hex.
    package static func uriComponent(_ text: String) -> String {
        var unreserved = CharacterSet(charactersIn: "-_.!~*'()")
        unreserved.formUnion(CharacterSet(charactersIn: "a" ... "z"))
        unreserved.formUnion(CharacterSet(charactersIn: "A" ... "Z"))
        unreserved.formUnion(CharacterSet(charactersIn: "0" ... "9"))
        // Only an unpaired surrogate fails, and a Swift String cannot hold one.
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }
}
