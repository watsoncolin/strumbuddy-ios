---
tags: [strumbuddy, roadmap]
updated: 2026-10-04
---
# Roadmap

## v0.1 — engine + structured path + coach
**Done & on device:** [[Tuner]], [[Chord Detection]], [[Cleanliness Scoring]],
[[Muted-String Detection]], [[Chord Library]] diagrams, **engine → [[The Coach]]
loop for chords** (observations → consistency mastery → live recommendations).

**Also done & on device:** [[Rhythm Mode]] — metronome + transition drill
(records transition/timing observations).

**Done (retention-first, see [[Learning Philosophy]]):**
- ✅ **[[Daily Practice Loop]]** — "Today" session generator + streaks/forgiveness.
- ✅ **First-run onboarding** — manufactures the session-one win.
- ✅ **[[Structured Path]]** — Couch-to-5K-style gated, actionable ladder.

- ✅ **Beginner tips** + contextual hints (sore fingers etc.).
- ✅ **[[Songs]]** — graded bar-by-bar play-along, practice/full speed, goal song
  feeding the coach (restored Oct 2026 after the June removal).
- ✅ **[[Chord Preview]]** — "Hear it" physically-modelled strum.
- ✅ **[[Structured Path]] to 8 stages** + **tempo ladder** ([[Rhythm Mode]]).
- ✅ **Coach's diagnosis** after drills/songs/sessions ([[The Coach]]).
- ✅ **[[Progress]]** — one-minute changes + progress screen.
- ✅ **Onboarding placement** for returning players ([[The Coach]]).

- ✅ **Timing calibration** — user-calibrated `inputLatency` (drill setup → Calibrate timing).

✅ Reminders/notifications (June). ✅ Per-chord grading in songs (Oct).

**Next:**
1. **Device pass** on the October features (song play-along, tempo ladder,
   one-minute counting, preview-doesn't-score).
2. **Strumming patterns** — needs an engine signal first; deliberately not on the
   path until it can be graded.
3. v2 bring-your-own-song.

_Recital mode: dropped — the consistency-based practice grading covers that ground._

**Thesis to validate:** does explainable adaptive coaching keep a beginner
practicing longer than a generic lesson plan?

## v2 — bring-your-own-song
Analyze user-supplied audio → chord timeline → **chord simplifier** (vocabulary
reduction + capo placement) in difficulty tiers, personalized to known chords.
Feeds [[The Coach]] as goal-relevant skills. Chords only, no lyrics; analyzed
on-device.

## Later
LLM coach (data-grounded explanations), passive listening, ear training,
monetization.
