import Foundation
import Testing

@testable import BatteryCore

@Suite struct LiveRefreshPolicyTests {
    /// A window's interval and the menu bar's.
    static let window: Duration = .seconds(2)
    static let menuBar: Duration = .seconds(10)

    @Test(arguments: [ThermalState.nominal, .fair])
    func keepsTheIntervalWhileNothingAsksToSave(thermal: ThermalState) {
        for base in [Self.window, Self.menuBar] {
            #expect(LiveRefreshPolicy.interval(base: base, reducesResources: false, thermal: thermal) == base)
        }
    }

    @Test func slowsDownUnderLowPowerModeOrReducedResources() {
        #expect(LiveRefreshPolicy.interval(base: Self.window, reducesResources: true, thermal: .nominal) == .seconds(5))
        #expect(
            LiveRefreshPolicy.interval(base: Self.menuBar, reducesResources: true, thermal: .nominal) == .seconds(30))
    }

    @Test(arguments: [ThermalState.serious, .critical])
    func slowsDownWhenHot(thermal: ThermalState) {
        #expect(LiveRefreshPolicy.interval(base: Self.window, reducesResources: false, thermal: thermal) == .seconds(5))
        #expect(
            LiveRefreshPolicy.interval(base: Self.menuBar, reducesResources: false, thermal: thermal) == .seconds(30))
        // Both reasons at once slow it down no further.
        #expect(LiveRefreshPolicy.interval(base: Self.window, reducesResources: true, thermal: thermal) == .seconds(5))
    }

    @Test func onlySeriousOrWorseHeatCounts() {
        let slowing = ThermalState.allCases.filter(LiveRefreshPolicy.slowsDown(for:))
        #expect(slowing == [.serious, .critical])
    }

    @Test func neverPollsFasterThanAsked() {
        let bases: [Duration] = [.milliseconds(500), .seconds(1), .seconds(2), .seconds(3), .seconds(10), .seconds(60)]
        for base in bases {
            for thermal in ThermalState.allCases {
                for reduces in [false, true] {
                    #expect(LiveRefreshPolicy.interval(base: base, reducesResources: reduces, thermal: thermal) >= base)
                }
            }
            #expect(LiveRefreshPolicy.reduced(base) > base)
        }
    }

    /// Demo Mode simulates Low Power Mode and heat in its snapshots; the app's poll follows the
    /// system's. Every call in the app passes inputs that come from the system, none from a
    /// snapshot, a reading or the demo.
    @Test func theAppAsksWithTheSystemsState() throws {
        let calls = try SourceScanner.files.get().flatMap { file in
            SourceScanner.calls(named: #/LiveRefreshPolicy\.interval/#, in: file.code).map { (file.path, $0) }
        }
        #expect(calls.count >= 2, "The windows' modifier and the menu bar label")
        for (path, call) in calls {
            let arguments = call.arguments.lowercased()
            for source in ["snapshot", "reading", "demo"] {
                #expect(!arguments.contains(source), "\(path): \(call.arguments)")
            }
        }
    }
}
