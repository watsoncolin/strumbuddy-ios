---
tags: [strumbuddy, coach, curriculum]
updated: 2026-06-07
---
# Structured Path

The guided curriculum — a **Couch-to-5K-style ladder** (see [[Learning Philosophy]]).
The "Your Path" tab. Status: **built.** Complements [[The Coach]]: the path is the
*ordered map*, the coach is the *adaptive diagnosis*; both read the same mastery.

## How it works
- **Stages** (`Stage.beginnerStages`): First chords → First changes → Keep the beat
  → Widen the vocabulary. Each stage is a set of skills.
- **Completion = mastery** (the consistency criterion, not a separate test): a stage
  is complete when *all* its skills are mastered. This is why the §8 "assessment UX"
  worry dissolves — milestones pass through normal practice, no high-stakes test.
- **Sequential gating** (`computeStagePlans`, pure/tested): the first not-complete
  stage after a run of complete ones is **active**; later stages are **locked**.
- **Actionable**: the active stage's skills each launch the right pre-targeted tool
  (chord → [[Chord Detection|Chord Check]], transition/tempo → [[Rhythm Mode|drill]]),
  with per-skill mastery checks. This is the bridge from "here's the milestone" to
  "go play it."

## Relationship to the [[Daily Practice Loop]]
The daily loop is the *ritual* (what you do today); the path is the *journey* (where
you are overall). The loop's coach picks within whatever the path has unlocked.
