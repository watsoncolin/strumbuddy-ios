---
tags: [strumbuddy, chords, reference]
updated: 2026-06-07
---
# Chord Library

The constrained beginner set (`Models/Chord.swift`, `Models/ChordShape.swift`).
Kept tiny on purpose — template-matching a fixed set beats universal recognition
(see [[Chord Detection]]). Strings low E → high E; `x` = muted, `0` = open.

| Chord | Frets (E A D G B e) | Fingers | Notes |
| --- | --- | --- | --- |
| E | 0 2 2 1 0 0 | –,2,3,1,–,– | E G# B |
| Em | 0 2 2 0 0 0 | –,2,3,–,–,– | E G B |
| A | x 0 2 2 2 0 | –,–,1,2,3,– | A C# E |
| Am | x 0 2 2 1 0 | –,–,2,3,1,– | A C E |
| D | x x 0 2 3 2 | –,–,–,1,3,2 | D F# A |
| G | 3 2 0 0 0 3 | 2,1,–,–,–,3 | G B D |
| C | x 3 2 0 1 0 | –,3,2,–,1,– | C E G |
| F | 1 3 3 2 1 1 (barre 1) | 1,3,4,2,1,1 | F A C |

Rendered by `ChordDiagramView` (with string-name labels). Fingerings are
harness-verified: every shape sounds exactly its chord tones. `ChordShape` also
exposes `soundingPitchClass(forString:)` and open-string frequencies, used by the
finger-naming feedback and [[Muted-String Detection]].
