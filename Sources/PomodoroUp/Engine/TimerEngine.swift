import Foundation
import Observation
#if canImport(AppKit)
import AppKit
#endif
import PomodoroFormula

/// Drives the count-up work session / countdown break state machine.
///
/// Time is always *derived* from wall-clock timestamps (`phaseStartDate` +
/// `clock.now()`), never accumulated tick-by-tick, so missed timer fires,
/// app suspension, or system sleep self-heal on the next `tick()` rather
/// than leaving the displayed time stale or wrong.
@Observable
public final class TimerEngine {

    public enum Phase: Equatable, Sendable {
        case idle
        case working
        case onBreak
    }

    public private(set) var phase: Phase = .idle
    public private(set) var elapsedSeconds: Double = 0
    public private(set) var currentTargetMinutes: Double
    public private(set) var currentBreakMinutes: Double
    public private(set) var isOverTarget: Bool = false

    /// Fired exactly once per work session, the instant elapsed time first
    /// reaches the target.
    public var onTargetCrossed: (() -> Void)?
    /// Fired exactly once when a break's countdown reaches zero.
    public var onBreakEnded: (() -> Void)?
    /// Fired once a work session ends (user-initiated stop), with the
    /// resulting record ready to persist.
    public var onSessionCompleted: ((WorkSessionRecord) -> Void)?

    private let clock: EngineClock
    private let constantsProvider: () -> AdjustmentFormula.Constants
    private var phaseStartDate: Date?
    private var hasFiredTargetCrossedThisSession = false
    private var pendingNextTargetMinutes: Double?

    private var repeatingTimer: Timer?
    #if canImport(AppKit)
    private var wakeObserver: NSObjectProtocol?
    #endif

    public init(
        clock: EngineClock = SystemClock(),
        constantsProvider: @escaping () -> AdjustmentFormula.Constants = { .defaults }
    ) {
        self.clock = clock
        self.constantsProvider = constantsProvider
        let baseline = constantsProvider()
        self.currentTargetMinutes = baseline.targetMinutes
        self.currentBreakMinutes = baseline.breakMinutes
    }

    deinit {
        repeatingTimer?.invalidate()
        #if canImport(AppKit)
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        #endif
    }

    // MARK: - Public control

    public func startWork() {
        guard phase == .idle else { return }
        let baseline = constantsProvider()
        currentTargetMinutes = pendingNextTargetMinutes ?? baseline.targetMinutes
        pendingNextTargetMinutes = nil
        elapsedSeconds = 0
        isOverTarget = false
        hasFiredTargetCrossedThisSession = false
        phaseStartDate = clock.now()
        phase = .working
        recomputeElapsed()
    }

    public func stopWork() {
        guard phase == .working else { return }
        recomputeElapsed()

        let baseline = constantsProvider()
        let actualWorkMinutes = elapsedSeconds / 60
        let overrunMinutes = max(0, actualWorkMinutes - currentTargetMinutes)
        let result = AdjustmentFormula.compute(overrunMinutes: overrunMinutes, constants: baseline)

        let record = WorkSessionRecord(
            startDate: phaseStartDate ?? clock.now(),
            endDate: clock.now(),
            baseTargetMinutes: currentTargetMinutes,
            actualWorkSeconds: elapsedSeconds,
            overrunSeconds: overrunMinutes * 60,
            baseBreakMinutes: baseline.breakMinutes,
            adjustedBreakMinutes: result.nextBreakMinutes,
            nextTargetMinutes: result.nextTargetMinutes
        )

        pendingNextTargetMinutes = result.nextTargetMinutes
        currentBreakMinutes = result.nextBreakMinutes

        onSessionCompleted?(record)

        elapsedSeconds = 0
        phaseStartDate = clock.now()
        phase = .onBreak
        recomputeElapsed()
    }

    /// Immediately ends the break and returns to idle, ready to start the
    /// next (already-adjusted) work session. Distinct from the automatic
    /// end-of-break transition — this is a user-initiated skip.
    public func skipBreak() {
        guard phase == .onBreak else { return }
        transitionToIdleAfterBreak()
    }

    /// Call when the active preset changes (e.g. the user picks a different
    /// one from the dropdown). Discards any overrun-adjusted target queued
    /// from the previous preset's just-finished session, so the next
    /// `startWork()` cleanly reflects the newly selected preset's raw
    /// target rather than a stale adjustment. Covers `.onBreak` as well as
    /// `.idle` — `pendingNextTargetMinutes` can be set in either phase — but
    /// is a no-op mid-session: there's nothing pending while `.working`.
    public func presetDidChange() {
        guard phase != .working else { return }
        pendingNextTargetMinutes = nil
    }

    /// idle -> startWork(), working -> stopWork(), onBreak -> skipBreak().
    /// Single contextual entry point for e.g. a global hotkey.
    public func performPrimaryAction() {
        switch phase {
        case .idle: startWork()
        case .working: stopWork()
        case .onBreak: skipBreak()
        }
    }

    /// Re-derives elapsed time from the wall clock and fires any
    /// transitions/callbacks that should have happened since the last call.
    /// The host (app/view layer) is responsible for calling this
    /// periodically; tests call it directly against a fake clock.
    public func tick() {
        recomputeElapsed()
    }

    /// Starts a real, always-on 1-second ticker plus a wake-from-sleep
    /// listener. Call once from the app root; safe to call only once.
    public func startAutoTicking() {
        guard repeatingTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatingTimer = timer

        #if canImport(AppKit)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tick()
        }
        #endif
    }

    // MARK: - Derived state

    public var remainingBreakSeconds: Double {
        guard phase == .onBreak else { return 0 }
        return max(0, currentBreakMinutes * 60 - elapsedSeconds)
    }

    /// The target the next work session will start with — useful for idle-state
    /// UI to show what's coming up, since it may differ from the baseline
    /// setting after an overrun adjustment.
    public var upcomingTargetMinutes: Double {
        pendingNextTargetMinutes ?? constantsProvider().targetMinutes
    }

    /// overrun-minutes / target-minutes while working past target; 0
    /// otherwise. Unbounded — callers (e.g. a progress ring) are
    /// responsible for clamping to whatever visual max they want.
    public var overrunRatio: Double {
        guard phase == .working, currentTargetMinutes > 0 else { return 0 }
        let overrunMinutes = max(0, elapsedSeconds / 60 - currentTargetMinutes)
        return overrunMinutes / currentTargetMinutes
    }

    // MARK: - Internal

    private func recomputeElapsed() {
        guard let start = phaseStartDate else { return }
        elapsedSeconds = clock.now().timeIntervalSince(start)

        switch phase {
        case .working:
            let targetSeconds = currentTargetMinutes * 60
            let nowOverTarget = elapsedSeconds >= targetSeconds
            if nowOverTarget != isOverTarget {
                isOverTarget = nowOverTarget
            }
            if nowOverTarget && !hasFiredTargetCrossedThisSession {
                hasFiredTargetCrossedThisSession = true
                onTargetCrossed?()
            }
        case .onBreak:
            if elapsedSeconds >= currentBreakMinutes * 60 {
                transitionToIdleAfterBreak()
            }
        case .idle:
            break
        }
    }

    private func transitionToIdleAfterBreak() {
        phase = .idle
        elapsedSeconds = 0
        phaseStartDate = nil
        isOverTarget = false
        onBreakEnded?()
    }
}
