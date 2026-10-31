import Foundation
import Observation

/// Observable state behind the menu bar badge and its menu, refreshed from the usage
/// ports on a fixed interval.
///
/// It holds the ports, not adapters, so `ClaudeUsageBarCoreTests` drives it with fakes and
/// `App/` hands it the keychain and `URLSession` adapters. What the state reads like is
/// ``UsagePresentation``'s job; this type decides when to ask and what an answer does to
/// the state.
@MainActor
@Observable
public final class UsageMenuViewModel {
    /// The three ports the menu bar item needs, gathered so the initializer stays short.
    public struct Ports: Sendable {
        let tokenProvider: any OAuthTokenProviding
        let usageFetcher: any UsageFetching
        let terminator: any ApplicationTerminating

        public init(
            tokenProvider: any OAuthTokenProviding,
            usageFetcher: any UsageFetching,
            terminator: any ApplicationTerminating,
        ) {
            self.tokenProvider = tokenProvider
            self.usageFetcher = usageFetcher
            self.terminator = terminator
        }
    }

    /// The numbers, the last failure, and when the numbers arrived.
    public private(set) var state = UsageState()

    /// The window the badge shows; ``BadgeWindow/weekly`` at every launch.
    public private(set) var badgeWindow = BadgeWindow.weekly

    /// ``state`` as the badge and the menu render it.
    public var presentation: UsagePresentation {
        UsagePresentation(state: state, formatter: formatter, badgeWindow: badgeWindow)
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

    /// Reads the token, fetches the usage, and publishes the result.
    ///
    /// A success replaces the numbers and clears the failure; a failure is recorded
    /// beside the last good numbers rather than instead of them; a cancellation changes
    /// nothing. The error — never the token or a response body — is logged `.public`:
    /// every case is a fixed name and at most a status code.
    public func refresh() async {
        do throws(UsageError) {
            let token = try await ports.tokenProvider.accessToken()
            let snapshot = try await ports.usageFetcher.fetchUsage(with: token).snapshot()
            state = UsageState(snapshot: snapshot, failure: nil, lastUpdated: now())
            AppLog.usage.info("refresh succeeded")
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

    /// Makes the badge show `window` — the menu's badge window choice.
    public func showInMenuBar(_ window: BadgeWindow) {
        badgeWindow = window
    }

    /// Quits the app — the menu's last item.
    public func quit() {
        ports.terminator.terminate()
    }
}
