import XCTest
@testable import PomodoroUp
import PomodoroFormula

final class TimerEngineTests: XCTestCase {

    let constants = AdjustmentFormula.Constants.defaults // target=20, break=5

    func makeEngine(clock: FakeClock) -> TimerEngine {
        TimerEngine(clock: clock, constantsProvider: { [constants] in constants })
    }

    func testStartsIdleAtBaselineTarget() {
        let engine = makeEngine(clock: FakeClock())
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.currentTargetMinutes, constants.targetMinutes)
    }

    func testStartWorkBeginsCountingUpFromZero() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.startWork()
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.elapsedSeconds, 0, accuracy: 0.001)

        clock.advance(seconds: 90)
        engine.tick()
        XCTAssertEqual(engine.elapsedSeconds, 90, accuracy: 0.001)
    }

    func testStartWorkIsNoOpWhenNotIdle() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.startWork()
        clock.advance(seconds: 10)
        engine.tick()
        engine.startWork() // should be ignored, still working, elapsed unaffected
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.elapsedSeconds, 10, accuracy: 0.001)
    }

    func testOnTargetCrossedFiresExactlyOnceWhenPassingTarget() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        var crossedCount = 0
        engine.onTargetCrossed = { crossedCount += 1 }

        engine.startWork()
        XCTAssertFalse(engine.isOverTarget)

        clock.advance(minutes: 19)
        engine.tick()
        XCTAssertFalse(engine.isOverTarget)
        XCTAssertEqual(crossedCount, 0)

        clock.advance(minutes: 2) // now at 21 minutes, past the 20 minute target
        engine.tick()
        XCTAssertTrue(engine.isOverTarget)
        XCTAssertEqual(crossedCount, 1)

        clock.advance(minutes: 5) // still over target, should not refire
        engine.tick()
        XCTAssertEqual(crossedCount, 1)
    }

    func testStopWorkWithNoOverrunKeepsBaselineTargetAndBreak() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        var completed: WorkSessionRecord?
        engine.onSessionCompleted = { completed = $0 }

        engine.startWork()
        clock.advance(minutes: 15) // under target, no overrun
        engine.tick()
        engine.stopWork()

        XCTAssertEqual(engine.phase, .onBreak)
        XCTAssertEqual(engine.currentBreakMinutes, constants.breakMinutes, accuracy: 0.0001)
        XCTAssertEqual(engine.upcomingTargetMinutes, constants.targetMinutes, accuracy: 0.0001)
        XCTAssertEqual(completed?.overrunSeconds, 0)
        XCTAssertEqual(completed?.baseTargetMinutes, constants.targetMinutes)
    }

    func testStopWorkWithOverrunMatchesFormulaOutput() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        var completed: WorkSessionRecord?
        engine.onSessionCompleted = { completed = $0 }

        engine.startWork()
        let overrunMinutes = 8.0
        clock.advance(minutes: constants.targetMinutes + overrunMinutes)
        engine.tick()
        engine.stopWork()

        let expected = AdjustmentFormula.compute(overrunMinutes: overrunMinutes, constants: constants)

        XCTAssertEqual(engine.currentBreakMinutes, expected.nextBreakMinutes, accuracy: 0.0001)
        XCTAssertEqual(engine.upcomingTargetMinutes, expected.nextTargetMinutes, accuracy: 0.0001)
        XCTAssertEqual(completed?.nextTargetMinutes ?? -1, expected.nextTargetMinutes, accuracy: 0.0001)
        XCTAssertEqual(completed?.adjustedBreakMinutes ?? -1, expected.nextBreakMinutes, accuracy: 0.0001)
        XCTAssertEqual(completed?.overrunSeconds ?? -1, overrunMinutes * 60, accuracy: 0.01)
    }

    func testNextWorkSessionStartsAtAdjustedTargetNotBaseline() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)

        engine.startWork()
        clock.advance(minutes: constants.targetMinutes + 8) // overrun -> target should shrink
        engine.tick()
        engine.stopWork()
        let adjustedTarget = engine.upcomingTargetMinutes
        XCTAssertLessThan(adjustedTarget, constants.targetMinutes)

        // finish the break to return to idle, then start again
        clock.advance(minutes: engine.currentBreakMinutes)
        engine.tick()
        XCTAssertEqual(engine.phase, .idle)

        engine.startWork()
        XCTAssertEqual(engine.currentTargetMinutes, adjustedTarget, accuracy: 0.0001)
    }

    func testBreakAutoEndsExactlyOnceAndReturnsToIdle() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        var breakEndedCount = 0
        engine.onBreakEnded = { breakEndedCount += 1 }

        engine.startWork()
        clock.advance(minutes: 10) // no overrun, break = baseline 5 min
        engine.tick()
        engine.stopWork()
        XCTAssertEqual(engine.phase, .onBreak)

        clock.advance(minutes: 3)
        engine.tick()
        XCTAssertEqual(engine.phase, .onBreak)
        XCTAssertEqual(breakEndedCount, 0)
        XCTAssertGreaterThan(engine.remainingBreakSeconds, 0)

        clock.advance(minutes: 3) // total 6 minutes into a 5 minute break
        engine.tick()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(breakEndedCount, 1)
        XCTAssertEqual(engine.remainingBreakSeconds, 0)

        clock.advance(minutes: 10) // idle should never re-fire onBreakEnded
        engine.tick()
        XCTAssertEqual(breakEndedCount, 1)
    }

    func testSkipBreakEndsBreakImmediately() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        var breakEndedCount = 0
        engine.onBreakEnded = { breakEndedCount += 1 }

        engine.startWork()
        clock.advance(minutes: 10)
        engine.tick()
        engine.stopWork()
        XCTAssertEqual(engine.phase, .onBreak)

        engine.skipBreak()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(breakEndedCount, 1)
    }

    func testPresetDidChangeClearsPendingAdjustmentWhileOnBreak() {
        let clock = FakeClock()
        var activeConstants = constants
        let engine = TimerEngine(clock: clock, constantsProvider: { activeConstants })

        engine.startWork()
        clock.advance(minutes: constants.targetMinutes + 8) // overrun -> pending adjustment set
        engine.tick()
        engine.stopWork()
        XCTAssertEqual(engine.phase, .onBreak)
        XCTAssertLessThan(engine.upcomingTargetMinutes, constants.targetMinutes)

        // Simulate switching to a different preset with a different baseline target.
        var newConstants = constants
        newConstants.targetMinutes = 30
        activeConstants = newConstants
        engine.presetDidChange()

        XCTAssertEqual(engine.upcomingTargetMinutes, 30, accuracy: 0.0001)
    }

    func testPresetDidChangeClearsPendingAdjustmentWhileIdle() {
        let clock = FakeClock()
        var activeConstants = constants
        let engine = TimerEngine(clock: clock, constantsProvider: { activeConstants })

        engine.startWork()
        clock.advance(minutes: constants.targetMinutes + 8)
        engine.tick()
        engine.stopWork()
        clock.advance(minutes: engine.currentBreakMinutes)
        engine.tick()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertLessThan(engine.upcomingTargetMinutes, constants.targetMinutes)

        var newConstants = constants
        newConstants.targetMinutes = 25
        activeConstants = newConstants
        engine.presetDidChange()

        XCTAssertEqual(engine.upcomingTargetMinutes, 25, accuracy: 0.0001)
    }

    func testPresetDidChangeIsNoOpWhileWorking() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.startWork()
        clock.advance(minutes: 5)
        engine.tick()
        let targetBefore = engine.currentTargetMinutes

        engine.presetDidChange()

        XCTAssertEqual(engine.currentTargetMinutes, targetBefore)
        XCTAssertEqual(engine.phase, .working)
    }

    func testPerformPrimaryActionDispatchesByPhase() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)

        engine.performPrimaryAction()
        XCTAssertEqual(engine.phase, .working)

        clock.advance(minutes: 10)
        engine.tick()
        engine.performPrimaryAction()
        XCTAssertEqual(engine.phase, .onBreak)

        engine.performPrimaryAction()
        XCTAssertEqual(engine.phase, .idle)
    }

    func testOverrunRatioIsZeroBeforeAndUpToTarget() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        XCTAssertEqual(engine.overrunRatio, 0)

        engine.startWork()
        XCTAssertEqual(engine.overrunRatio, 0)

        clock.advance(minutes: constants.targetMinutes)
        engine.tick()
        XCTAssertEqual(engine.overrunRatio, 0, accuracy: 0.0001)
    }

    func testOverrunRatioReflectsOverrunWhileWorking() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.startWork()

        clock.advance(minutes: constants.targetMinutes * 1.4) // 40% overrun
        engine.tick()
        XCTAssertEqual(engine.overrunRatio, 0.4, accuracy: 0.001)
    }

    func testOverrunRatioIsZeroOutsideWorkingPhase() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.startWork()
        clock.advance(minutes: constants.targetMinutes * 2)
        engine.tick()
        engine.stopWork()

        XCTAssertEqual(engine.phase, .onBreak)
        XCTAssertEqual(engine.overrunRatio, 0)
    }

    func testStopWorkIsNoOpWhenNotWorking() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        var completedCount = 0
        engine.onSessionCompleted = { _ in completedCount += 1 }

        engine.stopWork() // idle, should be ignored
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(completedCount, 0)
    }
}
