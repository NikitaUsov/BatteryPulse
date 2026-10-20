#if os(macOS)
import BatteryCore
import Testing

@testable import BatteryKit

/// Runs on CI's macOS, a virtual machine that may have no battery: only the plumbing is checked.
@MainActor
@Suite struct MacBatteryProviderTests {
    @Test func observationCancels() {
        let observation = MacBatteryProvider().observeChanges {}
        observation.cancel()
        observation.cancel()
    }

    /// A live read finds the battery whenever a full one does; only its SMC part differs.
    @Test func bothScopesFindTheSameBattery() {
        let provider = MacBatteryProvider()
        let full = provider.read()
        let live = provider.read(scope: .live)
        #expect((full == nil) == (live == nil))
        #expect(full?.smc.keys.sorted() == live?.smc.keys.sorted(), "the live read keeps the full read's other keys")
    }
}
#endif
