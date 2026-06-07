---
tags: [strumbuddy, audio, cleanliness]
updated: 2026-06-07
---
# Cleanliness Scoring

The **differentiator**: not "right/wrong" but *how* you played it. Status:
**working on device.** Part of [[Chord Detection]].

## Per-note quality
From the chromagram, each note in the target [[Chord Library|chord]] is graded:
- **clean** — expected pitch class present above `presenceThreshold`
- **muted** — expected pitch class missing (dead/dampened string)
- **buzzing** — an *unexpected* pitch class ringing loudly (wrong fret / stray note)

`ChordCheckView` shows these as colored pills and turns them into actionable text,
e.g. *"Your D string (4th) isn't ringing — press your middle finger down firmer."*

## Peak-hold (sensitivity)
`ChordScoreSmoother` keeps the **cleanest instant** of a strum and holds it ~1.6s,
instead of averaging the decaying note. More forgiving (one good strum) yet still
honest — a persistently muted string never rings in any frame. See [[Decisions]].

## Knobs
`presenceThreshold` (0.28), `buzzThreshold` (0.5), `playingRMS` (0.006).
