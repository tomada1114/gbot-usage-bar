/// Which usage window the menu bar badge shows. The menu lists both either way.
///
/// The choice lasts for the app's run only: nothing is saved, so every launch starts on
/// ``weekly``.
public enum BadgeWindow: Sendable {
    /// The rolling five-hour window (`five_hour`).
    case fiveHour
    /// The weekly window (`seven_day`), the default.
    case weekly

    /// The order the menu offers them in, matching the usage lines above: weekly first.
    public static let menuOrder: [Self] = [.weekly, .fiveHour]
}
