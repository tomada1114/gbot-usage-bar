import Foundation

/// One weekly reading from the desktop app's cache, as Core decoded it.
public struct CachedUsage: Equatable, Sendable {
    /// The weekly window.
    public let weekly: UsageWindow
    /// When the desktop app fetched it.
    public let readAt: Date
    /// When the desktop app itself stops trusting it, or `nil` when the cache did not say.
    public let expiresAt: Date?

    public init(weekly: UsageWindow, readAt: Date, expiresAt: Date?) {
        self.weekly = weekly
        self.readAt = readAt
        self.expiresAt = expiresAt
    }
}
