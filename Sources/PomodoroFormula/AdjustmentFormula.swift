import Foundation

/// Pure, UI-agnostic computation of how a work session's overrun should
/// reshape the next work target and the next break length.
///
/// Given `r = overrun / targetMinutes`:
///   - the next target dips below the base target, peaking around `r == p`,
///     then eases back up toward the base target for very large overruns
///     (a big overrun never permanently cripples the next session).
///   - the next break grows quickly at first, then saturates at an absolute
///     cap of `breakMinutes + breakCapBonus` (it never exceeds that cap).
public enum AdjustmentFormula {

    public struct Constants: Equatable, Codable, Sendable {
        public var targetMinutes: Double
        public var breakMinutes: Double
        /// Controls how deep the target dip goes at its peak.
        public var kt: Double
        /// Overrun ratio (overrun / target) at which the target dip peaks.
        /// Smaller p = the dip peaks sooner *and* eases back sooner.
        public var p: Double
        /// The maximum amount (in minutes) the break can grow by, asymptotically.
        public var breakCapBonus: Double
        /// Controls how quickly the break bonus approaches its cap.
        /// Smaller q = the break grows faster at the start.
        public var q: Double

        public init(
            targetMinutes: Double = 20,
            breakMinutes: Double = 5,
            kt: Double = 2.0,
            p: Double = 0.4,
            breakCapBonus: Double = 5,
            q: Double = 0.3
        ) {
            self.targetMinutes = targetMinutes
            self.breakMinutes = breakMinutes
            self.kt = kt
            self.p = p
            self.breakCapBonus = breakCapBonus
            self.q = q
        }

        public static let defaults = Constants()

        // MARK: - Control-point-friendly derived properties
        // These express the same curve in terms a future draggable graph
        // editor can bind to directly, without changing storage shape.

        /// x-location (overrun minutes) of the target curve's deepest dip.
        public var targetDipPeakOverrunMinutes: Double { p * targetMinutes }

        /// y-depth (minutes below base target) at the target curve's deepest dip.
        public var targetDipPeakMagnitudeMinutes: Double {
            targetMinutes * kt * p / M_E
        }

        /// The break curve's horizontal asymptote — its maximum possible value.
        public var breakCapMinutes: Double { breakMinutes + breakCapBonus }

        /// x-location (overrun minutes) at which the break curve has closed
        /// half the gap to its cap.
        public var breakHalfLifeOverrunMinutes: Double {
            q * log(2) * targetMinutes
        }

        /// Reshapes the target curve so its peak dip sits at the given point.
        public mutating func setTargetDipPeak(overrunMinutes: Double, dipMinutes: Double) {
            guard targetMinutes > 0, overrunMinutes > 0 else { return }
            let newP = overrunMinutes / targetMinutes
            p = newP
            kt = (dipMinutes * M_E) / (targetMinutes * newP)
        }

        /// Reshapes the break curve so it reaches half its cap at the given overrun.
        public mutating func setBreakHalfLife(overrunMinutes: Double) {
            guard targetMinutes > 0, overrunMinutes > 0 else { return }
            let r = overrunMinutes / targetMinutes
            q = r / log(2)
        }
    }

    public struct Result: Equatable, Sendable {
        public let nextTargetMinutes: Double
        public let nextBreakMinutes: Double
        public let overrunRatio: Double
    }

    /// - Parameters:
    ///   - overrunMinutes: how far past the target the caller's session ran
    ///     (already relative to whatever target was in effect that session —
    ///     the caller is responsible for that subtraction). Negative values
    ///     are treated as zero (no overrun).
    ///   - constants: the fixed baseline constants (target/break/curve shape)
    ///     that the resulting curves are anchored to. Always deriving from
    ///     the fixed baseline — rather than a previously-adjusted target —
    ///     keeps repeated overruns from compounding into permanent drift.
    public static func compute(overrunMinutes: Double, constants: Constants) -> Result {
        let target = constants.targetMinutes
        guard target > 0 else {
            return Result(nextTargetMinutes: target, nextBreakMinutes: constants.breakMinutes, overrunRatio: 0)
        }

        let overrun = max(0, overrunMinutes)
        let r = overrun / target

        let targetShrink: Double
        if constants.p > 0 {
            targetShrink = target * constants.kt * r * exp(-r / constants.p)
        } else {
            targetShrink = 0
        }
        let nextTarget = max(0, target - targetShrink)

        let breakBonus: Double
        if constants.q > 0 {
            breakBonus = constants.breakCapBonus * (1 - exp(-r / constants.q))
        } else {
            breakBonus = r > 0 ? constants.breakCapBonus : 0
        }
        let nextBreak = constants.breakMinutes + breakBonus

        return Result(nextTargetMinutes: nextTarget, nextBreakMinutes: nextBreak, overrunRatio: r)
    }
}
