---
tags: [strumbuddy, audio, chords]
updated: 2026-06-07
---
# Chord Detection

The polyphonic path of the [[Audio Engine]]. Status: **working on device.**

## How it works
- `Chromagram` runs a vDSP FFT and folds bins into **12 pitch-class energies**
  (octave-folded). We [[Decisions|hand-rolled it]] on Accelerate.
- `ChordDetector` **template-matches** the chroma against the [[Chord Library]]
  (a tiny fixed set — far more accurate than universal recognition).
- `score(chord:)` returns identity **confidence** (accuracy axis) plus
  [[Cleanliness Scoring|cleanliness]] and per-note quality.

## Verified (off-device harness)
All 8 chords identified on synthesized harmonic-rich tones (confidence .79–.89),
including the classic confusions (C vs Am, Em vs G).

## Limitation
Pitch-class detection is octave-blind — it can't tell *which string* sounds a
note. That gap is addressed by [[Muted-String Detection]].
