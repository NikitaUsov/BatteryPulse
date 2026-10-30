#if os(macOS)
import Testing

@testable import BatterySource

/// Runs on CI's macOS: the runner has no accessories, so only the plumbing is checked.
@MainActor
@Suite struct MacAccessoryProviderTests {
    /// A reading (likely empty) rather than `nil` proves the private function exists on this
    /// macOS.
    @Test func readReturnsAReading() {
        #expect(MacAccessoryProvider().read() != nil)
    }

    @Test func observationCancels() {
        let observation = MacAccessoryProvider().observeChanges {}
        observation.cancel()
        observation.cancel()
    }
}
#endif
