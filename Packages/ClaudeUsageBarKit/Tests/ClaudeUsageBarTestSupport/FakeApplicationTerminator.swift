import ClaudeUsageBarCore
import os

/// The one fake of ``ClaudeUsageBarCore/ApplicationTerminating``: it counts the requests
/// instead of ending the process running the tests.
package final class FakeApplicationTerminator: ApplicationTerminating {
    /// How many times ``terminate()`` has been asked so far.
    package var terminateCount: Int {
        calls.withLock { $0 }
    }

    private let calls = OSAllocatedUnfairLock(initialState: 0)

    package init() {
        // Stateless apart from the count.
    }

    package func terminate() {
        calls.withLock { $0 += 1 }
    }
}
