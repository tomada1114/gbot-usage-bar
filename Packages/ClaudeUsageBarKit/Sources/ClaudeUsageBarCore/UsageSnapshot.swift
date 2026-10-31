import Foundation

/// One rate-limit window as the usage endpoint reports it.
public struct UsageWindow: Equatable, Sendable {
    /// The largest percent the menu bar shows: three digits is what the badge is sized
    /// for, and a value past it is already "over the limit" to a reader.
    public static let maximumPercent = 999

    /// How much of the window is used, in percent (0–100 in practice; not clamped here).
    public let utilization: Double
    /// When the window resets, or `nil` when the endpoint did not say or said something
    /// unreadable.
    public let resetsAt: Date?

    /// The whole percent a reader sees: rounded half away from zero, and kept within
    /// `0 ... maximumPercent` so a negative, huge, or non-finite value can neither show
    /// a minus sign nor trap in the `Int` conversion.
    public var percent: Int {
        let bounded = min(max(utilization.rounded(), 0), Double(Self.maximumPercent))
        return bounded.isNaN ? 0 : Int(bounded)
    }

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
}

/// The two windows this app shows, from one successful refresh.
public struct UsageSnapshot: Equatable, Sendable {
    /// The rolling five-hour window (`five_hour`).
    public let fiveHour: UsageWindow?
    /// The weekly window (`seven_day`) — the menu bar's number by default.
    public let sevenDay: UsageWindow?

    public init(fiveHour: UsageWindow?, sevenDay: UsageWindow?) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }
}
