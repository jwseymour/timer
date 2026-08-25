import SwiftUI
import PomodoroFormula

/// Preset list + editor. A future draggable curve editor (v2) will bind to
/// the same per-preset `AdjustmentFormula.Constants` via the control-point
/// properties already exposed there.
struct AdvancedSettingsView: View {
    @Environment(AppSettingsStore.self) private var store

    /// Deliberately separate from `store.selectedPresetID` — browsing/
    /// editing a preset here shouldn't itself change which preset is
    /// active. Only the dropdown's quick-select does that.
    @State private var editingPresetID: Preset.ID?

    var body: some View {
        VStack(spacing: 0) {
            presetsSplitView
            Divider()
            GlobalHotkeySection()
                .padding(12)
        }
        .frame(width: 520, height: 480)
    }

    private var presetsSplitView: some View {
        NavigationSplitView {
            List(selection: $editingPresetID) {
                ForEach(store.presets, id: \.id) { (preset: Preset) in
                    HStack {
                        Text(preset.name)
                        if preset.id == store.selectedPresetID {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .help("Currently active")
                        }
                    }
                    .tag(preset.id)
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        let new = store.addPreset(named: "New Preset")
                        editingPresetID = new.id
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    Button {
                        guard let id = editingPresetID, let copy = store.duplicatePreset(id: id) else { return }
                        editingPresetID = copy.id
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .disabled(editingPresetID == nil)
                    Button(role: .destructive) {
                        guard let id = editingPresetID else { return }
                        store.deletePreset(id: id)
                        editingPresetID = nil
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(editingPresetID == nil || store.presets.count <= 1)
                }
            }
        } detail: {
            if let binding = presetBinding {
                PresetEditorView(preset: binding)
            } else {
                ContentUnavailableView("Select a Preset", systemImage: "slider.horizontal.3")
            }
        }
        .onAppear {
            if editingPresetID == nil {
                editingPresetID = store.selectedPresetID
            }
        }
        .frame(height: 400)
    }

    private var presetBinding: Binding<Preset>? {
        guard let id = editingPresetID, let preset = store.presets.first(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { store.presets.first(where: { $0.id == id }) ?? preset },
            set: { store.updatePreset($0) }
        )
    }
}

private struct PresetEditorView: View {
    @Binding var preset: Preset

    var body: some View {
        Form {
            Section("Preset") {
                TextField("Name", text: $preset.name)
            }

            Section("Session") {
                LabeledContent("Work target (minutes)") {
                    TextField("", value: $preset.constants.targetMinutes, format: .number)
                        .frame(width: 70)
                }
                LabeledContent("Base break (minutes)") {
                    TextField("", value: $preset.constants.breakMinutes, format: .number)
                        .frame(width: 70)
                }
            }

            Section {
                CurveGraphView(
                    title: "Next target vs. overrun — drag the dip",
                    xRange: targetXRange,
                    yRange: targetYRange,
                    curve: { AdjustmentFormula.compute(overrunMinutes: $0, constants: preset.constants).nextTargetMinutes },
                    controlPoints: [targetDipControlPoint]
                )
                Text("Dips \(preset.constants.targetDipPeakMagnitudeMinutes, specifier: "%.1f") min at \(preset.constants.targetDipPeakOverrunMinutes, specifier: "%.1f") min overrun, then eases back to normal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                CurveGraphView(
                    title: "Next break vs. overrun — drag the ramp and the cap",
                    xRange: breakXRange,
                    yRange: breakYRange,
                    curve: { AdjustmentFormula.compute(overrunMinutes: $0, constants: preset.constants).nextBreakMinutes },
                    controlPoints: [breakHalfLifeControlPoint, breakCapControlPoint]
                )
                Text("Reaches half its bonus at \(preset.constants.breakHalfLifeOverrunMinutes, specifier: "%.1f") min overrun, capped at \(preset.constants.breakCapMinutes, specifier: "%.1f") min total.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Overrun curve")
            } footer: {
                Text("Drag the orange point to reshape how far the next target dips and when. Drag the blue point to control how fast the break ramps up, and the green point to set its cap.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Reset to Defaults") {
                preset.constants = .defaults
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Graph ranges

    private var targetXRange: ClosedRange<Double> {
        let c = preset.constants
        let upper = max(c.targetDipPeakOverrunMinutes * 3, c.targetMinutes * 0.5, 1)
        return 0...upper
    }

    private var targetYRange: ClosedRange<Double> {
        0...max(preset.constants.targetMinutes * 1.05, 1)
    }

    private var breakXRange: ClosedRange<Double> {
        let c = preset.constants
        let upper = max(c.breakHalfLifeOverrunMinutes * 3, c.targetMinutes * 0.5, 1)
        return 0...upper
    }

    private var breakYRange: ClosedRange<Double> {
        0...max(preset.constants.breakCapMinutes * 1.1, 1)
    }

    // MARK: - Control points

    /// Dragging reshapes both where the target's dip peaks (x) and how deep
    /// it goes (y) — a free-drag point mapped back to k_t/p via
    /// `setTargetDipPeak`.
    private var targetDipControlPoint: CurveGraphView.ControlPoint {
        let c = preset.constants
        return CurveGraphView.ControlPoint(
            id: "targetDip",
            position: CGPoint(x: c.targetDipPeakOverrunMinutes, y: c.targetMinutes - c.targetDipPeakMagnitudeMinutes),
            dragAxis: .free,
            color: .orange,
            onChange: { newPosition in
                let dipMinutes = max(0, preset.constants.targetMinutes - newPosition.y)
                let overrunMinutes = max(0.1, newPosition.x)
                preset.constants.setTargetDipPeak(overrunMinutes: overrunMinutes, dipMinutes: dipMinutes)
            }
        )
    }

    /// Horizontal-only drag: controls how quickly the break ramps up (q),
    /// via `setBreakHalfLife`. Its y position always sits at exactly half
    /// the current cap bonus, by definition of "half-life".
    private var breakHalfLifeControlPoint: CurveGraphView.ControlPoint {
        let c = preset.constants
        return CurveGraphView.ControlPoint(
            id: "breakHalfLife",
            position: CGPoint(x: c.breakHalfLifeOverrunMinutes, y: c.breakMinutes + c.breakCapBonus / 2),
            dragAxis: .horizontal,
            color: .accentColor,
            onChange: { newPosition in
                let overrunMinutes = max(0.1, newPosition.x)
                preset.constants.setBreakHalfLife(overrunMinutes: overrunMinutes)
            }
        )
    }

    /// Vertical-only drag: sets the break's absolute cap directly
    /// (`breakCapBonus`). Fixed near the right edge of the graph — the cap
    /// is a horizontal asymptote, not tied to a specific overrun amount.
    private var breakCapControlPoint: CurveGraphView.ControlPoint {
        let c = preset.constants
        let fixedX = breakXRange.upperBound * 0.85
        return CurveGraphView.ControlPoint(
            id: "breakCap",
            position: CGPoint(x: fixedX, y: c.breakCapMinutes),
            dragAxis: .vertical,
            color: .green,
            onChange: { newPosition in
                preset.constants.breakCapBonus = max(0, newPosition.y - preset.constants.breakMinutes)
            }
        )
    }
}

private struct GlobalHotkeySection: View {
    @Environment(GlobalHotkeyMonitor.self) private var monitor
    @State private var isGranted = InputMonitoringPermission.isGranted

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Global Hotkey").font(.headline)
                Spacer()
                Circle()
                    .fill(isGranted ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(isGranted ? "Granted" : "Not granted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("⌃⌥Space toggles start/stop/skip-break from anywhere, without touching the mouse.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if isGranted {
                    Toggle("Enabled", isOn: Binding(
                        get: { monitor.isRunning },
                        set: { $0 ? monitor.start() : monitor.stop() }
                    ))
                } else {
                    Button("Request Access") {
                        InputMonitoringPermission.request()
                        isGranted = InputMonitoringPermission.isGranted
                    }
                    Button("Open System Settings") {
                        InputMonitoringPermission.openSystemSettings()
                    }
                }
            }
        }
        .onAppear {
            isGranted = InputMonitoringPermission.isGranted
            if isGranted { monitor.start() }
        }
    }
}
