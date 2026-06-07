---
tags: [strumbuddy, audio, engine]
updated: 2026-06-07
---
# Audio Engine

The shared capability everything sits on (`Audio/AudioEngine.swift`). Captures the
mic via `AVAudioEngine`, extracts **one** sample buffer, and fans it to two paths:

- **Monophonic** → `PitchDetector` ([[Tuner]]) — a single fundamental.
- **Polyphonic** → `Chromagram` → `ChordDetector` ([[Chord Detection]],
  [[Cleanliness Scoring]], [[Muted-String Detection]]).

## Principles
- **Pure DSP cores.** `PitchDetector`, `Chromagram`, `ChordDetector` take plain
  `[Float]` samples — no AVFoundation — so they're unit-tested off-device in
  `scripts/main.swift`. See [[Decisions]].
- **First-party only.** FFT via Accelerate/vDSP; we [[Decisions|hand-rolled the chromagram]].
- **Smoothing lives at the edges.** `PitchSmoother` (median + hold) and
  `ChordScoreSmoother` (peak-hold) keep live readouts stable.

## The four scoring axes
Every observation is graded on **accuracy, cleanliness, timing, consistency**.
These feed both milestone tests and [[The Coach]]. Cleanliness is the
differentiator — see [[Cleanliness Scoring]].

## Tuning knobs
`presenceThreshold`, `buzzThreshold`, `mutedRingThreshold` (in `ChordDetector`),
`playingRMS` / `minClarity` (in `AudioEngine`), `PitchDetector.minRMS`. All single
constants, dialed by ear on-device.
