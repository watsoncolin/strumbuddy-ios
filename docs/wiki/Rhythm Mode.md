---
tags: [strumbuddy, audio, coach]
updated: 2026-06-07
---
# Rhythm Mode

Metronome + transition drill — playing *in time*, and the source of the timing &
transition observations that make [[The Coach|credit assignment]] real. Status:
**built; verify on device.**

## Metronome
`Metronome` (+ pure [[Glossary|BeatClock]]) drives a steady beat with an accented
downbeat — audible (synthesized click via a dedicated `AVAudioPlayerNode`) and
visible (`beatInBar`). A Free Play tool (Tuner | Chords | Metro). Click verified
clicking on device.

## Transition drill
The high-value activity: change between two chords in time (where beginners stall).
Launched from the **Practice** tab.

- `DrillSchedule` (pure): a count-in bar, then alternating bars; maps each downbeat
  to record-this-rep / start-that-rep / finished (no off-by-ones in the live code).
- `DrillSession` subscribes to the metronome, switches the target chord each bar,
  and grades the bar: **accuracy + cleanliness** from the engine (peak-hold best of
  the bar) and **timing** from `BeatClock.alignment` (when the best strum landed vs
  the beat).
- Each rep records a transition `Observation` — `[transition(A→B), chord(A),
  chord(B), tempoHold(bpm)]`, context `inSequence` — feeding [[The Coach]]. This is
  what lets it say *"your C is fine; it's the change into it under tempo."*

## Known refinement
Timing uses a fixed `inputLatency` (~0.09s) to estimate capture time. It's coarse
and calibratable by ear; precise on-beat grading may need tuning. See [[Decisions]].
