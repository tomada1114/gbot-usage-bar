/// Every number someone might want to tweak, in one place (`designing-core-logic`).
public struct Tuning: Sendable, Equatable {
    /// The shipped values, in seconds; the properties below say why each is what it is.
    private enum ShippedSeconds {
        static let refreshInterval = 60
        static let requestTimeout = 30
    }

    /// Every value as shipped.
    public static let `default` = Self(
        refreshInterval: .seconds(ShippedSeconds.refreshInterval),
        requestTimeout: .seconds(ShippedSeconds.requestTimeout),
    )

    /// How long the menu bar waits between refreshes. One minute keeps the number
    /// fresh enough for a weekly and a five-hour window while sending the undocumented
    /// endpoint about 1,440 requests a day — the same order as Claude Code's own status
    /// line refreshing while it runs.
    public var refreshInterval: Duration

    /// How long one request may take before it counts as unreachable. Shorter than the
    /// refresh interval, so a hung request never overlaps the next refresh.
    public var requestTimeout: Duration

    public init(refreshInterval: Duration, requestTimeout: Duration) {
        self.refreshInterval = refreshInterval
        self.requestTimeout = requestTimeout
    }
}
