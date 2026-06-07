# Strumbuddy — Claude Code guide

iOS app that listens to acoustic guitar and coaches the player. Read
`docs/design-doc.md` first — it's the source of truth for *why* the architecture
is shaped this way. This file is the *how*.

## Build / regenerate

The Xcode project is generated from `project.yml` via XcodeGen. After adding,
removing, or moving files, regenerate:

```sh
xcodegen generate
```

Build from the command line:

```sh
xcodegen generate
xcodebuild -project Strumbuddy.xcodeproj -scheme Strumbuddy \
  -destination 'generic/platform=iOS Simulator' build
```

The mic only works on a real device; the tuner/engine will run but detect nothing
in the simulator.

### Off-device tests for pure audio/DSP math

The pitch detector and tuner math are written as pure, dependency-light types so
they can be tested on macOS without a device or simulator runtime:

```sh
swiftc -O Strumbuddy/Models/Chord.swift Strumbuddy/Models/ScoreAxes.swift \
       Strumbuddy/Audio/Chromagram.swift Strumbuddy/Audio/ChordDetector.swift \
       Strumbuddy/Audio/PitchDetector.swift Strumbuddy/Features/Shared/TunerReading.swift \
       scripts/main.swift -o /tmp/check && /tmp/check
```

`scripts/` is intentionally outside the app target. Keep DSP logic in pure types
(no AVFoundation) so it stays testable this way.

## Conventions

- SwiftUI, iOS 16+, MVVM-lite. `@MainActor` on the stateful services
  (`AudioEngine`, `Metronome`, `ObservationLog`, `Coach`).
- Bundle ID `me.colinwatson.strumbuddy`, team `M7PCWQ7WYN` (matches pourcraft-ios).
- **No third-party dependencies in v0.1.** Audio is AVFoundation + Accelerate/vDSP
  only (licensing — see design-doc §4). Don't add AudioKit without a reason; if you
  do, it's the commented block in `project.yml`.
- The `.xcodeproj` is committed but generated — never hand-edit it; change
  `project.yml` and regenerate.

## Map

- `Audio/` — the shared engine. `AudioEngine` extracts one sample buffer and fans it
  to `PitchDetector` (monophonic YIN → tuner) and `Chromagram` → `ChordDetector`
  (polyphonic → chord identity + cleanliness). `PitchSmoother` / `ChordScoreSmoother`
  stabilize the live readouts. `ScoringService` produces the four-axis `ScoreAxes`
  and builds `Observation`s. All DSP cores are pure (no AVFoundation) and tested via
  `scripts/main.swift`.
- `Coach/` — the heart. `SkillGraph` (transitions are first-class nodes),
  `ObservationLog` (append-only, the source of truth), `MasteryStore` (projects the
  log into `MasteryState` with FSRS decay), `CreditAssignment` (apportions blame),
  `SelectionPolicy` (the "work on…" ranking), `Coach` (facade the UI uses).
- `Models/` — `Chord`, `Skill`/`SkillID`, `Observation`, `MasteryState`, `ScoreAxes`.
- `Features/` — the three mode screens.
- `Persistence/` — SQLite plan; v0.1 uses JSON via `ObservationLog`.

## Open questions (marked `OPEN QUESTION` in code, tracked in design-doc §8)

- Credit-assignment inference (`Coach/CreditAssignment.swift`) — currently a simple
  explainable heuristic; the principled version is a knowledge-tracing model.
- Selection-policy weighting (`Coach/SelectionPolicy.swift`) — the four signal
  weights are placeholders to tune against real sessions.
