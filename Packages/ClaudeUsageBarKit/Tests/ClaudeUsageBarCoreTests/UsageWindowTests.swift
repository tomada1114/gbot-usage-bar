import ClaudeUsageBarCore
import Testing

/// The one number a reader sees for a window.
@Suite("UsageWindow")
struct UsageWindowTests {
    @Test(arguments: [
        (76.0, 76),
        (0.0, 0),
        (0.4, 0),
        (0.5, 1),
        (75.5, 76),
        (99.6, 100),
        (100.0, 100),
        (123.2, 123),
        (-3.0, 0),
        (-0.6, 0),
        (998.9, 999),
        (123_456.0, 999),
        (1e300, 999),
        (-1e300, 0),
    ])
    func `the displayed percent is rounded and kept within zero to three digits`(
        utilization: Double,
        expected: Int,
    ) {
        #expect(UsageWindow(utilization: utilization, resetsAt: nil).percent == expected)
    }
}
