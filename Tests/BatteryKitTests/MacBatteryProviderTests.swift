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

    /// The monitor's reads run off the main actor, through the provider itself, and may meet a
    /// read on the main actor: reads from several threads at once agree on the battery.
    @Test func readsFromSeveralThreadsAgree() async {
        let provider = MacBatteryProvider()
        #expect(provider.nonisolatedReader != nil)
        let hasBattery = provider.read() != nil
        let found = await withTaskGroup(of: Bool.self) { group in
            for index in 0..<8 {
                group.addTask { provider.readNonisolated(scope: index.isMultiple(of: 2) ? .live : .full) != nil }
            }
            var results: [Bool] = []
            for await result in group { results.append(result) }
            return results
        }
        #expect(found == Array(repeating: hasBattery, count: 8))
    }

    /// One SMC client serves several threads: they take turns on its connection.
    @Test func oneSMCClientServesSeveralThreads() async {
        let smc = SMCClient()
        let counts = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<8 {
                group.addTask { smc.read(SMCBattery.liveKeys).count }
            }
            var results: [Int] = []
            for await result in group { results.append(result) }
            return results
        }
        #expect(counts.count == 8)
        #expect(counts.allSatisfy { $0 <= SMCBattery.liveKeys.count })
    }
}
#endif
