---
tags: [strumbuddy, coach]
updated: 2026-06-07
---
# The Coach

The brain (`Coach/`). Status: **designed and scaffolded, not yet wired to the
engine** — this is the next major step.

Three stacked ideas: **knowledge tracing** (infer skill from noisy attempts),
**spaced repetition** (skills decay), and a **prerequisite graph**.

## Layers
1. **Skill graph** (`SkillGraph`) — atoms are micro-skills. Key call: **transitions
   are first-class nodes** (a G→C change has its own mastery, independent of G and
   C). The prereq DAG gates suggestions and explains *why* you're stuck.
2. **Mastery with decay** (`MasteryState`) — proficiency + confidence +
   `lastPracticed`, modeled FSRS-style. "Completed" is never permanent.
3. **Credit assignment** (`CreditAssignment`) — one strum is evidence about
   several skills; blame the right one ("your C is fine; it's the change"). The
   hardest, most differentiating piece. Currently a heuristic; see [[Glossary]].
4. **Selection policy** (`SelectionPolicy`) — "what to work on" = weakest-but-ready
   + decay-due + goal-relevant + bottleneck leverage. Explainable by construction.

## Data model
Append-only `ObservationLog`; mastery is a **projection** over it (event-sourcing),
so inference can be re-tuned and replayed. On-device SQLite planned (JSON for now).

## Next step
Have `ChordCheckView` (and the structured path) record each graded strum as an
`Observation` via `coach.record(...)`, feeding [[Cleanliness Scoring]] results into
credit assignment. See [[Roadmap]]. Open questions tracked in the [design doc §8](../design-doc.md).
