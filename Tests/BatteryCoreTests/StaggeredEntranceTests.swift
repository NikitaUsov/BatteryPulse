import BatteryCore
import Testing

@Suite struct StaggeredEntranceTests {
    @Test func rowsStartOneStepApart() {
        let entrance = StaggeredEntrance(MotionPolicy())
        #expect(entrance.plays)
        #expect(entrance.delay(forRow: 0) == 0)
        for index in 1..<6 {
            let gap = entrance.delay(forRow: index) - entrance.delay(forRow: index - 1)
            #expect(abs(gap - StaggeredEntrance.step) < 1e-9, "row \(index)")
        }
        #expect(entrance.opacityBeforeEntering == 0)
        #expect(entrance.offsetBeforeEntering == StaggeredEntrance.rise)
    }

    /// What's New has six rows: with the 0.35 s state-change animation, the last one is in place
    /// about half a second after the window appears.
    @Test func sixRowsSettleInAboutHalfASecond() {
        let entrance = StaggeredEntrance(MotionPolicy())
        #expect(entrance.delay(forRow: 5) + 0.35 <= 0.56)
    }

    @Test func longListsStopWaiting() {
        let entrance = StaggeredEntrance(MotionPolicy())
        #expect(entrance.delay(forRow: 40) == StaggeredEntrance.maximumDelay)
        #expect(entrance.delay(forRow: -1) == 0)
    }

    @Test(arguments: [
        MotionPolicy(reduceMotion: true),
        MotionPolicy(prefersCrossFade: true),
        MotionPolicy(isVisible: false),
        MotionPolicy(reducesResources: true),
    ])
    func rowsAreSimplyThereWithoutFlourish(policy: MotionPolicy) {
        let entrance = StaggeredEntrance(policy)
        #expect(!entrance.plays)
        #expect(entrance.delay(forRow: 3) == 0)
        #expect(entrance.opacityBeforeEntering == 1)
        #expect(entrance.offsetBeforeEntering == 0)
    }
}
