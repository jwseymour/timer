# PomodoroUp

[![CI](https://github.com/jwseymour/timer/actions/workflows/ci.yml/badge.svg)](https://github.com/jwseymour/timer/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.10-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A macOS menu bar work timer for people who don't want to be interrupted
mid-flow. Instead of a hard stop, it **counts up**: run past your target on
purpose, and the amount you overran smoothly reshapes your next break (longer,
capped) and next work target (shorter, then easing back to normal for very
large overruns).

## Features

- **Count-up timer in the menu bar** with a live progress ring and elapsed time
- **Adaptive breaks and targets** driven by a tunable overrun curve
- **Presets**, each with its own target, break, and curve constants
- **Draggable curve editor** for shaping the adjustment curves visually
- **Global hotkey** (⌃⌥Space) to start, stop, or skip a break from any app
- **Session history** persisted with SwiftData, in its own window by design
- **Sleep-safe engine**: wall-clock anchored, so it self-heals across sleep or missed ticks

## How the adjustment works

With overrun ratio `r = overrun / target`:

- **Next target** = `target − target·kt·r·e^(−r/p)` — dips, peaks around `r = p`,
  then recovers, so one huge overrun never cripples the next session.
- **Next break** = `break + cap·(1 − e^(−r/q))` — grows fast, then saturates at
  `break + cap`.

Adjustments are always derived from the fixed baseline, never from the previous
adjusted value, so repeated overruns can't compound into permanent drift. The
math lives in a pure, dependency-free module
(`Sources/PomodoroFormula/AdjustmentFormula.swift`) with its own unit tests.

## Tech

Swift 5.10 · SwiftUI · SwiftData · Swift Package Manager · XCTest · GitHub Actions CI.
The timer engine takes injectable clock and sound abstractions, so its state
machine is tested deterministically with a fake clock (34 tests total).

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
