import SwiftUI

/// The persistent live content shown in the actual macOS menu bar (top bar).
///
/// Takes `engine` as a direct parameter rather than via `@Environment` —
/// the MenuBarExtra label closure doesn't reliably inherit scene-level
/// `.environment()` injection the way normal window content does.
struct MenuBarLabelView: View {
    let engine: TimerEngine

    var body: some View {
        switch engine.phase {
        case .idle:
            Text("⏱︎")
        case .working:
            HStack(spacing: 4) {
                ProgressRingView(
                    innerProgress: engine.elapsedSeconds / (engine.currentTargetMinutes * 60),
                    outerProgress: engine.isOverTarget ? min(engine.overrunRatio, 1) : nil,
                    innerColor: TimeDisplayText.color(isOverTarget: engine.isOverTarget)
                )
                TimeDisplayText(elapsedSeconds: engine.elapsedSeconds, isOverTarget: engine.isOverTarget)
            }
        case .onBreak:
            HStack(spacing: 4) {
                ProgressRingView(
                    innerProgress: 1 - (engine.remainingBreakSeconds / (engine.currentBreakMinutes * 60)),
                    innerColor: .accentColor
                )
                Text("☕︎ " + TimeDisplayText.formatted(engine.remainingBreakSeconds))
                    .monospacedDigit()
            }
        }
    }
}
