---
tags: [strumbuddy, coach]
updated: 2026-10-04
---
# The Coach

The brain (`Coach/`). Status: **wired end to end** — Chord Check, the transition drill and song
play-alongs all record observations; the Practice tab shows live recommendations
and per-chord mastery, and every run ends with the coach's diagnosis.

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

## Diagnosis — the coach shows its work
`Coach/DrillDiagnosis.swift` (pure, tested) turns a graded run into one verdict,
shown as a **Coach's note** on drill and song summaries: clean / landing late on X /
rushing into X / unsteady timing / *"your X is solid on its own — it's the change
from Y"* / X itself needs work. Late vs. early comes from each bar's signed beat
offset (`RepResult.timingOffset`); chord-vs-change uses the coach's standalone
belief (≥0.7), mirroring credit assignment. The daily reward screen explains
tomorrow's pick ("Next up: X, because …"). Drill summaries add a rep strip.

## Evidence rules (Oct 2026)
- `Observation.score` — the one blended score everything learns from; **untimed
  attempts (no bpm) leave timing out** instead of a stand-in.
- Tempo evidence lands on the graph's hold levels (60/80/100); see [[Rhythm Mode]].
- A held chord in a song (G→G) is evidence about the chord only, never a "change".
- Song bars log with source `.song` ([[Songs]]).

## Goal song
`SongProgressStore` feeds the goal song's chords + changes to `setGoalSkills`
(previously never called). The goal signal only applies while a skill is unmastered.

## Placement (cold start)
Onboarding's "Have you played before?" step seeds known chords via
`Models/Placement.swift` (3 × 0.8 `.calibration` observations → mastered).
Self-correcting by design; changes are never seeded. See [[Decisions]].

## Open questions
Credit-assignment mechanism and selection-policy weights remain open — see the
[design doc §8](../design-doc.md). Diagnosis thresholds are untuned guesses.
