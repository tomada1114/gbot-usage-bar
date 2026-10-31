import ClaudeUsageBarCore
import Testing

@Suite("Tuning")
struct TuningTests {
    @Test
    func `the default polls every minute and gives a request thirty seconds`() {
        #expect(Tuning.default.refreshInterval == .seconds(60))
        #expect(Tuning.default.requestTimeout == .seconds(30))
    }
}
