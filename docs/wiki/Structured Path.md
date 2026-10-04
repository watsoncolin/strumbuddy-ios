---
tags: [strumbuddy, coach, curriculum]
updated: 2026-10-04
---
# Structured Path

The guided curriculum — a **Couch-to-5K-style ladder** (see [[Learning Philosophy]]).
The "Your Path" tab. Status: **built.** Complements [[The Coach]]: the path is the
*ordered map*, the coach is the *adaptive diagnosis*; both read the same mastery.

## How it works
- **Stages** (`Stage.beginnerStages`): First chords → First changes → Keep the beat
  (60) → Widen the vocabulary (D, A) → Minor moods (Am, E) → Pick up the pace (80)
  → The F barre → Song speed (100). Each stage is a set of skills; the harness checks
  every stage skill exists in the graph and every chord is on the path.
- **Tempo holds** drill *your* weakest change whose chords you already have
  (`Coach.transitionForTempoHold`), at the milestone tempo. Any drill or song at or
  above a level is evidence for it (`TempoLadder.holdLevel`), so a song at 65 bpm
  counts toward "hold 60".
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
