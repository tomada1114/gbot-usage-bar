import Foundation

/// What the app knows about the usage right now: the last good numbers, whether the most
/// recent refresh failed, and when the numbers arrived.
///
/// A failure does not erase the numbers: the menu keeps showing the last good ones beside
/// the line that says why they may be stale.
public struct UsageState: Equatable, Sendable {
    /// The last successfully fetched usage, or `nil` before the first success.
    public var snapshot: UsageSnapshot?
    /// Why the most recent refresh failed, or `nil` when it succeeded (or none has run).
    public var failure: UsageError?
    /// When ``snapshot`` arrived.
    public var lastUpdated: Date?

    public init(
        snapshot: UsageSnapshot? = nil,
        failure: UsageError? = nil,
        lastUpdated: Date? = nil,
    ) {
        self.snapshot = snapshot
        self.failure = failure
        self.lastUpdated = lastUpdated
    }
}
