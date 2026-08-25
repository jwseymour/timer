# PomodoroUp

A count-up work timer: run past a target on purpose when you're mid-task, and
the amount you overran smoothly reshapes your next break (grows, capped) and
next work target (dips, then eases back to normal for very large overruns).
Lives in the macOS menu bar.

## Running it

SwiftData requires a real `.app` bundle (an `Info.plist` with a bundle name)
to initialize — a bare `swift run`/`swift build` executable crashes on
launch. Use the bundling script instead:

```sh
./Scripts/build_app.sh          # debug build
open .build/PomodoroUp.app
```

Quit it the normal way: click the menu bar item → Quit PomodoroUp, or
`pkill -f PomodoroUp`.

## Development

```sh
swift build        # compiles fine as a bare executable for iteration
swift test          # runs the formula + timer engine unit tests
```

`swift build`/`swift test` are fine for iterating on code — you only need
`Scripts/build_app.sh` to actually *run* the app, because of the SwiftData
bundle requirement above.

## Structure

- `Sources/PomodoroFormula/` — the overrun-adjustment curve. Pure, no UI/
  persistence dependencies. Fully unit tested (`Tests/PomodoroFormulaTests`).
- `Sources/PomodoroUp/Engine/` — `TimerEngine` (the work/break state machine,
  wall-clock-anchored so it self-heals across sleep/missed ticks), plus
  sound and clock abstractions.
- `Sources/PomodoroUp/Models/` — SwiftData `WorkSession` history model.
- `Sources/PomodoroUp/Settings/` — `AppSettingsStore` (UserDefaults-backed
  presets, each with its own full set of target/break/curve constants) and
  `Preset`.
- `Sources/PomodoroUp/Hotkey/` — `GlobalHotkeyMonitor` (⌃⌥Space toggles
  start/stop/skip-break from anywhere) and `InputMonitoringPermission`, the
  TCC wrapper it needs (passive global key observation — distinct from
  Accessibility, which is for posting/synthesizing events).
- `Sources/PomodoroUp/Views/` — menu bar label (live progress ring + time)/
  dropdown (preset picker + controls), the full timer window, history
  window, and advanced settings (preset list/editor + curve graphs + hotkey
  permission UI) — each its own window, per design (history is deliberately
  never on the same screen as the timer).

## Advanced settings

Each preset's target/break durations are numeric fields; the overrun curve
shape is a draggable graph editor (`Views/Components/CurveGraphView.swift`)
with a few key control points per curve, bound through
`AdjustmentFormula.Constants`'s derived control-point properties
(`targetDipPeakOverrunMinutes`, `targetDipPeakMagnitudeMinutes`,
`breakCapMinutes`, `breakHalfLifeOverrunMinutes`) and inverse setters
(`setTargetDipPeak`, `setBreakHalfLife`) — no storage migration was needed
since those were built into the formula unit from the start.
