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

    static let scopes: [BatteryReadScope] = [.full, .live, .cached, .cachedSlow]

    /// Every scope finds the battery whenever a full read does; only what it fetches again differs.
    @Test func everyScopeFindsTheSameBattery() {
        let provider = MacBatteryProvider()
        // Before a read has fetched the registry, one that may reuse it fetches it.
        let first = provider.read(scope: .cached)
        let full = provider.read()
        #expect((first == nil) == (full == nil))
        for scope in Self.scopes {
            let reading = provider.read(scope: scope)
            #expect((full == nil) == (reading == nil))
            #expect(
                full?.smc.keys.sorted() == reading?.smc.keys.sorted(), "a read keeps the other keys it didn't ask for")
        }
    }

    /// A read that reuses the registry carries the dictionaries of the read that last fetched them.
    @Test func aCachedReadReusesTheLastFetchedRegistry() {
        let provider = MacBatteryProvider()
        // CI's virtual machine may have no battery: then there is nothing to reuse.
        guard let full = provider.read() else { return }
        for scope in [BatteryReadScope.cached, .cachedSlow] {
            let cached = provider.read(scope: scope)
            #expect(cached?.smartBattery == full.smartBattery)
            #expect(cached?.powerSource == full.powerSource)
            #expect(cached?.adapterDetails == full.adapterDetails)
        }
    }

    /// The monitor's reads run off the main actor, through the provider itself, and may meet a
    /// read on the main actor: reads from several threads at once agree on the battery.
    @Test func readsFromSeveralThreadsAgree() async {
        let provider = MacBatteryProvider()
        #expect(provider.nonisolatedReader != nil)
        let hasBattery = provider.read() != nil
        let found = await withTaskGroup(of: Bool.self) { group in
            for index in 0..<8 {
                let scope = Self.scopes[index % Self.scopes.count]
                group.addTask { provider.readNonisolated(scope: scope) != nil }
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
