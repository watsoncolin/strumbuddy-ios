---
tags: [strumbuddy, coach]
updated: 2026-06-07
---
# The Coach

The brain (`Coach/`). Status: **wired to the engine for chords** — Chord Check now
records each completed strum as an `Observation` and the Practice tab shows live
recommendations + per-chord mastery. Transitions/timing come with the metronome.

Three stacked ideas: **knowledge tracing** (infer skill from noisy attempts),
**spaced repetition** (skills decay), and a **prerequisite graph**.

## Layers
1. **Skill graph** (`SkillGraph`) — atoms are micro-skills. Key call: **transitions
   are first-class nodes** (a G→C change has its own mastery, independent of G and
   C). The prereq DAG gates suggestions and explains *why* you're stuck.
2. **Mastery with decay** (`MasteryState`) — proficiency + confidence +
   `lastPracticed`, modeled FSRS-style. "Completed" is never permanent. **Mastery is
   consistency-based**: clean on ≥3 of the last 4 attempts — robust to a fumble, and
   never earned off one lucky strum. Proficiency is a gentle EMA (rate 0.3), so a
   single bad rep only dents it ~0.04.
3. **Credit assignment** (`CreditAssignment`) — one strum is evidence about
   several skills; blame the right one ("your C is fine; it's the change"). The
   hardest, most differentiating piece. Currently a heuristic; see [[Glossary]].
4. **Selection policy** (`SelectionPolicy`) — "what to work on" = weakest-but-ready
   + decay-due + goal-relevant + bottleneck leverage. Explainable by construction.

## Data model
Append-only `ObservationLog`; mastery is a **projection** over it (event-sourcing),
so inference can be re-tuned and replayed. On-device SQLite planned (JSON for now).

## Done & next
Chord observations now flow (`ChordCheckView` → `coach.record(...)`). Next: the
**metronome + transition drill** generate timing/transition observations, which is
what makes **credit assignment** real ("your C is fine; it's the *change* under
tempo"). Then **recital mode** — a deliberate assessment posture that gates
structured-path milestones (high-signal observations vs. forgiving practice). See
[[Roadmap]]. Open questions tracked in the [design doc §8](../design-doc.md).
