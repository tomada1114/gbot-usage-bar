import GbotUsageBarCore
import Testing

@Suite("Tuning")
struct TuningTests {
    @Test
    func `the default reads the cache every minute`() {
        #expect(Tuning.default.refreshInterval == .seconds(60))
    }
}
