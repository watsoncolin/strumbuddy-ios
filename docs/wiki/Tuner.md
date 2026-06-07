---
tags: [strumbuddy, audio, tuner]
updated: 2026-06-07
---
# Tuner

The monophonic path of the [[Audio Engine]]. Status: **working on device.**

## How it works
- `PitchDetector` runs **YIN** (cumulative-mean-normalized difference + absolute
  threshold + parabolic interpolation). Chosen over plain autocorrelation because
  it suppresses the octave errors that plague the low E string.
- `PitchSmoother` median-filters per-buffer estimates and **holds** the last
  stable pitch ~0.5s so the readout doesn't blink out as a note decays.
- `TunerView` shows note + octave, a cents needle with an in-tune zone, and the
  nearest standard-tuning string (`TunerReading`).

## Verified (off-device harness)
Accurate to ~0.1 cents on synthesized tones across all six open strings (incl.
low E), tracks detuning, rejects silence.

## Knobs
`PitchDetector.minRMS`, clarity gate (`AudioEngine.minClarity`), smoother
`holdFrames`.
