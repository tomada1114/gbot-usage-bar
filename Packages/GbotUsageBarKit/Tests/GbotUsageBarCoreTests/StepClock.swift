import os

/// A test clock whose sleeps return at once, recording each requested duration, until a
/// set number of them have passed; the next sleep then throws `CancellationError`, as a
/// real clock does for a cancelled task.
///
/// That makes a polling loop end deterministically after a known number of rounds,
/// with no real waiting and no race (`.claude/rules/testing.md` › Hygiene).
final class StepClock: Clock {
    struct Instant: InstantProtocol {
        let offset: Duration

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }

        func advanced(by duration: Duration) -> Self {
            Self(offset: offset + duration)
        }

        func duration(to other: Self) -> Duration {
            other.offset - offset
        }
    }

    private struct State {
        var now = Instant(offset: .zero)
        var sleeps: [Duration] = []
        var remaining: Int
    }

    /// Every duration a caller asked to sleep for, in order — the cancelled one included.
    var sleeps: [Duration] {
        state.withLock(\.sleeps)
    }

    var now: Instant {
        state.withLock(\.now)
    }

    var minimumResolution: Duration {
        .zero
    }

    private let state: OSAllocatedUnfairLock<State>

    /// Lets `sleepsBeforeStopping` sleeps pass, then throws from the next one.
    init(sleepsBeforeStopping: Int) {
        state = OSAllocatedUnfairLock(initialState: State(remaining: sleepsBeforeStopping))
    }

    func sleep(until deadline: Instant, tolerance _: Duration?) throws {
        let stop = state.withLock { state in
            state.sleeps.append(state.now.duration(to: deadline))
            guard state.remaining > 0 else {
                return true
            }
            state.remaining -= 1
            state.now = deadline
            return false
        }
        if stop {
            throw CancellationError()
        }
    }
}
