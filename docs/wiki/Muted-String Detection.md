---
tags: [strumbuddy, audio, cleanliness]
updated: 2026-06-07
---
# Muted-String Detection

Catches "**right note, wrong string**" — a string the chord says to mute that's
actually ringing. Status: **working on device.** Extends [[Cleanliness Scoring]].

## The problem
The [[Chord Detection|chromagram]] folds octaves away, so it can't tell a ringing
low E from a high E. In a **C chord** the muted low E sounds an *E* — a chord
tone — so pitch-class scoring says "fine" even though that booming bass string
shouldn't ring.

## The fix
`Chromagram.compute` now returns a `Spectrum` (chroma **+ raw FFT magnitudes** we
already computed and discarded). For each muted string, `ChordDetector` checks for
energy at that string's **open fundamental** (e.g. low E ≈ 82 Hz, ±1 semitone)
relative to the loudest in-range bin. Above `mutedRingThreshold` → flagged and
cleanliness penalized.

## Verified (off-device harness)
C + ringing low E → 6th string flagged, cleanliness 1.0 → 0.60, with no false
positive on a clean C.

## Scope
Targets the strings a chord *mutes* (mostly low strings), not full per-string
analysis (a single mic can't reliably do that). Knob: `mutedRingThreshold` (0.3).
