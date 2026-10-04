---
tags: [strumbuddy, audio, synth]
updated: 2026-10-04
---
# Chord Preview

"Hear it" — strums the chord in the diagram so a beginner knows what *clean* should
sound like. Status: **built; verify on device** (volume under the mic's
`.measurement` session, and that a preview doesn't score in Chord Check).

## Synth — `Audio/GuitarSynth.swift`
Physically modelled, pure (Foundation only), renders all 8 chords in ~70 ms.
Replaced an additive synth (`ChordSynth`: stacked sines, equal decay, bare triads)
that sounded like an organ — see [[Decisions]].
- **Per string, extended Karplus-Strong** using the real `ChordShape` voicing:
  integer delay + two-point averaging loss filter (highs die first) + first-order
  allpass for exact tuning; per-string T60 (≈5.5 s low E → ≈2.5 s high e).
- **Excitation = triangle at the pick point** (+ a little noise), ~1/n² harmonics.
  White noise was harpsichord-bright; see tuning history below.
- **Bridge pickup = derivative of displacement** → the ~1/n spectrum an acoustic
  radiates.
- **Strum** — strings staggered ~13 ms, velocity/timing/±1.5¢ humanization, muted
  strings give a short dead thud. Seeded RNG → deterministic renders.
- **Voicing** — broad body resonances (100/205/390 Hz, 2.8 kHz) and a 110 Hz
  high-pass + 6.5 kHz low-pass, voiced for a phone speaker.

## Playback — `Audio/ChordPreviewPlayer.swift`
Own `AVAudioEngine` + player node (like the metronome click), buffers cached per
chord. **Never downgrades the mic's `.playAndRecord` session** (only sets
`.playback` when the mic is idle) — `SynthPlayer` sets `.playback` unconditionally
and would cut capture. While a preview rings, `AudioEngine.suppressInput(for:)`
skips analysis and drops any in-progress strum so the phone's own strum isn't
graded. Button: `Features/Shared/ChordPreviewButton.swift` — in Chord Check, drill
setup, onboarding's first chord, chord detail, and [[Songs]] chord cards.

## Verified off-device (`scripts/main.swift`)
- Every open string reads within 3¢ on our own [[Tuner]] (measured ~0.03¢).
- Every strum is recognized clean by our [[Chord Detection|detector]] in ≥14/24
  windows, ≥80% overall (measured 166/192; G weakest at 15/24).

## Open questions
- Remaining misses look like a detector trait (power chroma, no harmonic
  suppression → overtones can outweigh a chord's third), not the synth. Does the
  detector miss real G/A strums the same way?
- `ChordSynth` (BYO-song reconstruction) still uses the old sound; it could strum
  through `GuitarSynth` with a voicing per chord symbol.
