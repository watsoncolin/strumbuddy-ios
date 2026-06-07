---
tags: [strumbuddy, decisions]
updated: 2026-06-07
---
# Decisions

Running log of choices and *why*, newest first.

- **Wiki in the repo as an Obsidian vault** (`docs/wiki/`) — knowledge travels with
  the code, version-controlled. Pair with `kepano/obsidian-skills` for idiomatic edits.
- **Muted-string detection via raw spectrum** — expose FFT magnitudes (already
  computed) to catch a ringing muted string by its fundamental frequency, since the
  octave-folded chroma can't. See [[Muted-String Detection]].
- **Peak-hold over EMA for chord scoring** — reward the cleanest instant of a strum
  rather than punishing natural decay; honest because a real mute never rings. See
  [[Cleanliness Scoring]].
- **AI hand images rejected** — explored Runware (FLUX, then Nano Banana / Gemini
  `google:4@1`). POV shots looked great but **none render correct fingerings**, and
  a wrong hand is worse than none. The deterministic [[Chord Library|chord diagram]]
  is the instructional source of truth. Image gen can't be trusted for *correctness*.
- **Hand-rolled chromagram on Accelerate/vDSP** — avoids Adam Stark's GPL-3 chord
  code; keeps v0.1 **dependency-free** and the DSP cores pure/testable.
- **Pure DSP cores, tested off-device** — `scripts/main.swift` compiles the pure
  types and asserts behavior on synthesized tones (no simulator runtime needed).
- **Name: Strumbuddy** — warm + guitar-obvious; chosen over the working title
  "Woodshed"; verified clear on the App Store.
- **Native `/voice` for dictation** — Claude Code's built-in voice (v2.1.69+),
  coding-tuned; no third-party Whisper app needed.

## Tuning constants (current)
`presenceThreshold 0.28` · `buzzThreshold 0.5` · `mutedRingThreshold 0.3` ·
`playingRMS 0.006` · `minClarity 0.5` · `PitchDetector.minRMS 0.003`. All dialed by
ear on device.
