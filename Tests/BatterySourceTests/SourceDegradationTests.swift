#if os(macOS)
import BatteryCore
import Testing

@testable import BatterySource

/// NEW-10's degradation half, on the Mac itself: a source that is missing reads as nothing, never
/// a crash; what the app shows for it is `DegradationTests`' (BatteryCoreTests, on Linux). CI's
/// macOS is a virtual machine, which may have no SMC and no battery.
@Suite struct SourceDegradationTests {
    /// Keys the SMC doesn't have read as nothing, the first time and every time after, beside
    /// the ones it has; with no SMC at all, every key does.
    @Test func keysTheSMCDoesNotHaveReadAsNothing() {
        let smc = SMCClient()
        let absent: [SMCFourCC] = ["ZZZ0", "ZZZ1"]
        #expect(smc.read(absent).isEmpty)
        #expect(smc.read(absent).isEmpty)
        #expect(smc.read(absent + SMCBattery.keys).allSatisfy { SMCBattery.keys.contains($0.key) })
    }
}
#endif
