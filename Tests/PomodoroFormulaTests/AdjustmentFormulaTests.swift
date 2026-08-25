import XCTest
@testable import PomodoroFormula

final class AdjustmentFormulaTests: XCTestCase {

    let defaults = AdjustmentFormula.Constants.defaults

    func testNoOverrunLeavesTargetAndBreakUnchanged() {
        let result = AdjustmentFormula.compute(overrunMinutes: 0, constants: defaults)
        XCTAssertEqual(result.nextTargetMinutes, defaults.targetMinutes, accuracy: 0.0001)
        XCTAssertEqual(result.nextBreakMinutes, defaults.breakMinutes, accuracy: 0.0001)
        XCTAssertEqual(result.overrunRatio, 0, accuracy: 0.0001)
    }

    func testNegativeOverrunIsTreatedAsZero() {
        let result = AdjustmentFormula.compute(overrunMinutes: -5, constants: defaults)
        XCTAssertEqual(result.overrunRatio, 0, accuracy: 0.0001)
    }

    func testTargetDipsBelowBaseNearThePeak() {
        // Peak overrun for defaults is p * target = 0.4 * 20 = 8 minutes.
        let peakOverrunMinutes = defaults.targetDipPeakOverrunMinutes
        let result = AdjustmentFormula.compute(
            overrunMinutes: peakOverrunMinutes,
            constants: defaults
        )
        XCTAssertLessThan(result.nextTargetMinutes, defaults.targetMinutes)
        XCTAssertEqual(
            defaults.targetMinutes - result.nextTargetMinutes,
            defaults.targetDipPeakMagnitudeMinutes,
            accuracy: 0.001,
            "at the formula's own peak overrun, the dip should equal the derived peak magnitude"
        )
    }

    func testTargetEasesBackTowardBaseForVeryLargeOverrun() {
        // A huge overrun (4x the target) should leave the next target
        // nearly back to normal, not permanently crippled.
        let result = AdjustmentFormula.compute(
            overrunMinutes: defaults.targetMinutes * 4,
            constants: defaults
        )
        XCTAssertEqual(result.nextTargetMinutes, defaults.targetMinutes, accuracy: 0.5)
    }

    func testBreakBonusNeverExceedsItsCapEvenForExtremeOverrun() {
        let result = AdjustmentFormula.compute(
            overrunMinutes: defaults.targetMinutes * 49,
            constants: defaults
        )
        XCTAssertLessThanOrEqual(result.nextBreakMinutes, defaults.breakCapMinutes + 0.0001)
        XCTAssertEqual(result.nextBreakMinutes, defaults.breakCapMinutes, accuracy: 0.01)
    }

    func testBreakGrowsMonotonicallyWithOverrun() {
        let overruns: [Double] = [1, 2, 5, 10, 15, 20, 30, 45]
        var previousBreak = defaults.breakMinutes
        for overrun in overruns {
            let result = AdjustmentFormula.compute(
                overrunMinutes: overrun,
                constants: defaults
            )
            XCTAssertGreaterThanOrEqual(result.nextBreakMinutes, previousBreak)
            previousBreak = result.nextBreakMinutes
        }
    }

    /// The user's explicit requirement: break growth must be the smaller
    /// effect relative to the target's shrink — specifically, the target's
    /// deepest dip must be more pronounced than the break's total cap bonus.
    func testTargetPeakDipExceedsBreakCapBonus() {
        XCTAssertGreaterThan(
            defaults.targetDipPeakMagnitudeMinutes,
            defaults.breakCapBonus,
            "break's max bonus must stay smaller than the target's peak dip, per the asymmetry requirement"
        )
    }

    func testBreakRampsUpFasterThanItApproachesAsymptote() {
        // With the tuned defaults, a modest 5-minute overrun should already
        // recover more than half of the break's total cap bonus.
        let result = AdjustmentFormula.compute(
            overrunMinutes: 5,
            constants: defaults
        )
        let bonusSoFar = result.nextBreakMinutes - defaults.breakMinutes
        XCTAssertGreaterThan(bonusSoFar, defaults.breakCapBonus * 0.5)
    }

    func testControlPointRoundTripForTargetDip() {
        var constants = defaults
        constants.setTargetDipPeak(overrunMinutes: 10, dipMinutes: 4)
        XCTAssertEqual(constants.targetDipPeakOverrunMinutes, 10, accuracy: 0.001)
        XCTAssertEqual(constants.targetDipPeakMagnitudeMinutes, 4, accuracy: 0.001)
    }

    func testControlPointRoundTripForBreakHalfLife() {
        var constants = defaults
        constants.setBreakHalfLife(overrunMinutes: 6)
        let result = AdjustmentFormula.compute(
            overrunMinutes: 6,
            constants: constants
        )
        let bonusSoFar = result.nextBreakMinutes - constants.breakMinutes
        XCTAssertEqual(bonusSoFar, constants.breakCapBonus * 0.5, accuracy: 0.001)
    }

    func testZeroTargetDoesNotCrash() {
        var constants = defaults
        constants.targetMinutes = 0
        let result = AdjustmentFormula.compute(overrunMinutes: 10, constants: constants)
        XCTAssertEqual(result.overrunRatio, 0)
    }

    func testRepeatedOverrunsDoNotCompoundDrift() {
        // Two consecutive maximal-dip overruns, each computed fresh against
        // the fixed baseline, should each independently land at the same
        // dipped target rather than drifting further down each time.
        let peakOverrunMinutes = defaults.targetDipPeakOverrunMinutes
        let first = AdjustmentFormula.compute(overrunMinutes: peakOverrunMinutes, constants: defaults)
        let second = AdjustmentFormula.compute(overrunMinutes: peakOverrunMinutes, constants: defaults)
        XCTAssertEqual(first.nextTargetMinutes, second.nextTargetMinutes, accuracy: 0.0001)
    }
}
