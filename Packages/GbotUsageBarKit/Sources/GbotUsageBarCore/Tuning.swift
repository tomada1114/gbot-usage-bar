/// Every number someone might want to tweak, in one place (`designing-core-logic`).
public struct Tuning: Sendable, Equatable {
    /// The shipped values, in seconds; the properties below say why each is what it is.
    private enum ShippedSeconds {
        static let refreshInterval = 60
    }

    /// Every value as shipped.
    public static let `default` = Self(refreshInterval: .seconds(ShippedSeconds.refreshInterval))

    /// How long the menu bar waits between reads of the cache. Reading two small local
    /// files is cheap, and a minute is well inside how often the desktop app itself
    /// refetches, so the badge never lags it by much.
    public var refreshInterval: Duration

    public init(refreshInterval: Duration) {
        self.refreshInterval = refreshInterval
    }
}
