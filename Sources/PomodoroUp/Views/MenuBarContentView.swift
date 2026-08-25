import SwiftUI
import AppKit

/// The dropdown panel shown when the menu bar item is clicked.
///
/// Takes `engine` as a direct parameter rather than via `@Environment` —
/// see `MenuBarLabelView` for why.
struct MenuBarContentView: View {
    let engine: TimerEngine
    @Environment(AppSettingsStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            presetPicker
            Divider()
            controls
            Divider()
            HStack {
                Button("Open Timer") { openWindow(id: WindowIDs.mainTimer) }
                Button("History") { openWindow(id: WindowIDs.history) }
            }
            SettingsLink {
                Text("Advanced Settings…")
            }
            Divider()
            Button("Quit PomodoroUp") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 230)
    }

    @ViewBuilder
    private var header: some View {
        switch engine.phase {
        case .idle:
            Text("Ready — next target \(Int(engine.upcomingTargetMinutes.rounded())) min")
                .font(.headline)
        case .working:
            VStack(alignment: .leading, spacing: 4) {
                Text("Working").font(.headline)
                TimeDisplayText(elapsedSeconds: engine.elapsedSeconds, isOverTarget: engine.isOverTarget, font: .title2)
                Text("Target: \(Int(engine.currentTargetMinutes.rounded())) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .onBreak:
            VStack(alignment: .leading, spacing: 4) {
                Text("On Break").font(.headline)
                Text(TimeDisplayText.formatted(engine.remainingBreakSeconds))
                    .font(.title2)
                    .monospacedDigit()
            }
        }
    }

    private var presetSelection: Binding<Preset.ID> {
        Binding(
            get: { store.selectedPresetID },
            set: { newID in
                store.selectPreset(id: newID)
                engine.presetDidChange()
            }
        )
    }

    private var presetPicker: some View {
        Picker("Preset", selection: presetSelection) {
            ForEach(store.presets) { preset in
                Text(preset.name).tag(preset.id)
            }
        }
        .labelsHidden()
    }

    @ViewBuilder
    private var controls: some View {
        switch engine.phase {
        case .idle:
            Button("Start Work") { engine.startWork() }
        case .working:
            Button("Stop") { engine.stopWork() }
        case .onBreak:
            Button("Skip Break") { engine.skipBreak() }
        }
    }
}
