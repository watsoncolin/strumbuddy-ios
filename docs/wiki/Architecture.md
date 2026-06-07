---
tags: [strumbuddy, architecture]
updated: 2026-06-07
---
# Architecture

**Three modes, one engine.** All surfaces sit on a single shared capability that
listens, identifies what was played, and grades it. They differ only in UI.

1. **Structured path** — staged milestones checked off by a test (a threshold on
   engine scores).
2. **Practice / the coach** — the "work on…" surface, driven by [[The Coach]].
3. **Free play** — pick and play; in v0.1 this hosts the [[Tuner]] and the Chord
   Check trainer. Becomes bring-your-own-song in v2 (see [[Roadmap]]).

Because the modes share the engine, most build cost is the [[Audio Engine]] and
[[The Coach]]; the modes are thin presentation layers.

## Code map
- `Audio/` — [[Audio Engine]] (mic capture, the two analysis paths, scoring)
- `Coach/` — [[The Coach]] (skill graph, mastery, credit assignment, policy)
- `Models/` — `Chord`, `Skill`, `Observation`, `MasteryState`, `ScoreAxes`, `ChordShape`
- `Features/` — the three mode screens

## Key constraint
v0.1 has **zero third-party dependencies** — audio is AVFoundation + Accelerate/
vDSP only (see [[Decisions]]).
