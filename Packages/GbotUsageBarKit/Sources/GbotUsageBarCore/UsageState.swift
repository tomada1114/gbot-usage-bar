import Foundation

/// What the app knows about the usage right now: the weekly numbers, whether the most
/// recent refresh failed, and when the desktop app read those numbers.
///
/// A failure does not erase the numbers: the menu keeps showing the last good ones beside
/// the line that says why they may be stale.
public struct UsageState: Equatable, Sendable {
    /// The weekly window, or `nil` before the first good read (or once it has reset).
    public var weekly: UsageWindow?
    /// Why the most recent refresh failed, or `nil` when it succeeded (or none has run).
    public var failure: UsageError?
    /// When the desktop app read ``weekly`` — not when this app read the cache, which
    /// happens every minute whether or not anything changed.
    public var lastUpdated: Date?

    public init(
        weekly: UsageWindow? = nil,
        failure: UsageError? = nil,
        lastUpdated: Date? = nil,
    ) {
        self.weekly = weekly
        self.failure = failure
        self.lastUpdated = lastUpdated
    }
}
