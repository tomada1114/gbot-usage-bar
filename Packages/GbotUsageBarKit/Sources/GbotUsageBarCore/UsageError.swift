/// Why the usage numbers could not be refreshed — the menu shows a different line for
/// each case, which is why this is an enum and not a message string.
///
/// Every port in the usage story throws exactly this type (`throws(UsageError)`), so the
/// view model's `switch` over it is exhaustive and a new case is a compile error at each
/// place that has to decide what it means. No case carries a file's contents, the
/// account slot, or a path.
public enum UsageError: Error, Equatable, Sendable {
    /// A cache file exists but could not be read (permissions, or an I/O error).
    case cacheUnreadable
    /// The refresh was cancelled before it finished. Not a failure: the caller keeps
    /// whatever it showed before, and nothing is logged.
    case cancelled
    /// The desktop app has saved no usage to read: its cache folder, its account slot,
    /// or the slot's weekly-usage entry is missing, or the entry says no reading is
    /// present. Opening the desktop app signed in fills it.
    case noCachedUsage
    /// The cached reading is older than the desktop app itself trusts (past its
    /// `expiresAtMs`), or the weekly window has reset since it was taken.
    case outOfDate
    /// A cache file was read but is not the JSON this app expects — the desktop app
    /// changed its format, or the file was caught mid-write.
    case unexpectedFormat
}
