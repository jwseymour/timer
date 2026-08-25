import SwiftUI

/// The full, native timer view — a distinct window from the menu bar
/// dropdown, deliberately not shown at launch (opened on demand).
struct MainTimerView: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        VStack(spacing: 24) {
            phaseLabel

            switch engine.phase {
            case .idle:
                TimeDisplayText(elapsedSeconds: 0, isOverTarget: false, font: .system(size: 64, weight: .thin, design: .rounded))
                Text("Next target: \(Int(engine.upcomingTargetMinutes.rounded())) min")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Start Work") { engine.startWork() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)

            case .working:
                TimeDisplayText(
                    elapsedSeconds: engine.elapsedSeconds,
                    isOverTarget: engine.isOverTarget,
                    font: .system(size: 64, weight: .thin, design: .rounded)
                )
                Text("Target: \(Int(engine.currentTargetMinutes.rounded())) min\(engine.isOverTarget ? " — over target" : "")")
                    .font(.title3)
                    .foregroundStyle(engine.isOverTarget ? .orange : .secondary)
                Button("Stop") { engine.stopWork() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)

            case .onBreak:
                Text(TimeDisplayText.formatted(engine.remainingBreakSeconds))
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .monospacedDigit()
                Text("Break: \(Int(engine.currentBreakMinutes.rounded())) min")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Skip Break") { engine.skipBreak() }
                    .controlSize(.large)
            }
        }
        .padding(48)
        .frame(minWidth: 420, minHeight: 320)
    }

    private var phaseLabel: some View {
        Text(phaseTitle)
            .font(.title2.bold())
    }

    private var phaseTitle: String {
        switch engine.phase {
        case .idle: return "Ready"
        case .working: return "Working"
        case .onBreak: return "On Break"
        }
    }
}
