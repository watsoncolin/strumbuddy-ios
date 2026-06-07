---
tags: [strumbuddy, reference]
updated: 2026-06-07
---
# Glossary

- **Chromagram** — energy in each of the 12 pitch classes, octave-folded. Backbone
  of [[Chord Detection]] and [[Cleanliness Scoring]]. We hand-rolled it on vDSP.
- **YIN** — monophonic pitch-detection algorithm used by the [[Tuner]]; robust
  against octave errors.
- **Pitch class** — a note name regardless of octave (all C's are pitch class C).
- **Constant-Q / FFT** — frequency analysis; we use a windowed real FFT (vDSP).
- **Four axes** — accuracy, cleanliness, timing, consistency (see [[Audio Engine]]).
- **Credit assignment** — apportioning one ambiguous attempt's evidence across the
  skills it implicates ([[The Coach]] §5.3).
- **Knowledge tracing** — inferring hidden skill from noisy attempts.
- **FSRS** — a spaced-repetition model (retrievability + stability); how mastery
  decays in [[The Coach]].
- **Peak-hold** — keep the best instant of a strum (see [[Cleanliness Scoring]]).
- **AIR id** — Runware's model identifier format (e.g. `google:4@1`); from the
  [[Decisions|AI-image experiment]].
