import Foundation
import Observation

/// Observable state behind the menu bar badge and its menu, refreshed from the usage
/// ports on a fixed interval.
///
/// It holds the ports, not adapters, so `GbotUsageBarCoreTests` drives it with fakes and
/// `App/` hands it the cache-folder adapter. What the state reads like is
/// ``UsagePresentation``'s job; this type decides when to ask and what an answer does to
/// the state.
@MainActor
@Observable
public final class UsageMenuViewModel {
    /// The two ports the menu bar item needs, gathered so the initializer stays short.
    public struct Ports: Sendable {
        let cacheReader: any CacheFileReading
        let terminator: any ApplicationTerminating

        public init(cacheReader: any CacheFileReading, terminator: any ApplicationTerminating) {
            self.cacheReader = cacheReader
            self.terminator = terminator
        }
    }

    /// The numbers, the last failure, and when the desktop app read the numbers.
    public private(set) var state = UsageState()

    /// ``state`` as the badge and the menu render it.
    public var presentation: UsagePresentation {
        UsagePresentation(state: state, formatter: formatter, now: now())
    }

    private let ports: Ports
    private let formatter: UsageFormatter
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Date
    private let tuning: Tuning
    @ObservationIgnored private var polling: Task<Void, Never>?

    /// Creates the view model. Nothing is asked until ``refresh()`` or
    /// ``startPolling()``: construction has no side effects.
    public init(
        ports: Ports,
        formatter: UsageFormatter = UsageFormatter(),
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping @Sendable () -> Date = { Date.now },
        tuning: Tuning = .default,
    ) {
        self.ports = ports
        self.formatter = formatter
        self.clock = clock
        self.now = now
        self.tuning = tuning
    }

    /// What a good read of `cached` means at `now`. Once the weekly window has reset its
    /// percent belongs to the old window, so it is dropped; once the desktop app's own
    /// expiry has passed the numbers stay, flagged as out of date.
    static func state(for cached: CachedUsage, at now: Date) -> UsageState {
        if let resetsAt = cached.weekly.resetsAt, resetsAt <= now {
            return UsageState(weekly: nil, failure: .outOfDate, lastUpdated: cached.readAt)
        }
        if let expiresAt = cached.expiresAt, expiresAt <= now {
            return UsageState(
                weekly: cached.weekly,
                failure: .outOfDate,
                lastUpdated: cached.readAt,
            )
        }
        return UsageState(weekly: cached.weekly, failure: nil, lastUpdated: cached.readAt)
    }

    /// Reads the desktop app's cache and publishes what it says.
    ///
    /// A good read replaces the numbers and clears the failure; a failure is recorded
    /// beside the last good numbers rather than instead of them; a cancellation changes
    /// nothing. The error — never a file's contents or the account slot — is logged
    /// `.public`: every case is a fixed name.
    public func refresh() async {
        do throws(UsageError) {
            let cached = try await UsageCache.read(from: ports.cacheReader)
            state = Self.state(for: cached, at: now())
            let outcome = state.failure.map { String(describing: $0) } ?? "current"
            AppLog.usage.info("refresh succeeded: \(outcome, privacy: .public)")
        } catch .cancelled {
            return
        } catch {
            state.failure = error
            AppLog.usage.error("refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Refreshes now, then again after every ``Tuning/refreshInterval``, until the task
    /// running it is cancelled — the one way it ends.
    public func run() async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await clock.sleep(for: tuning.refreshInterval)
            } catch {
                // Only cancellation interrupts a sleep, and it ends the loop.
                return
            }
        }
    }

    /// Starts ``run()`` in a task this view model owns, unless one is already running,
    /// and returns that task. The app calls it once at launch.
    @discardableResult
    public func startPolling() -> Task<Void, Never> {
        if let polling {
            return polling
        }
        let task = Task { await self.run() }
        polling = task
        return task
    }

    /// Cancels the polling task, if any, so ``startPolling()`` can start a fresh one.
    public func stopPolling() {
        polling?.cancel()
        polling = nil
    }

    /// Quits the app — the menu's last item.
    public func quit() {
        ports.terminator.terminate()
    }
}
