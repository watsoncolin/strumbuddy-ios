---
tags: [strumbuddy, roadmap]
updated: 2026-06-07
---
# Roadmap

## v0.1 — engine + structured path + coach
**Done & on device:** [[Tuner]], [[Chord Detection]], [[Cleanliness Scoring]],
[[Muted-String Detection]], [[Chord Library]] diagrams, **engine → [[The Coach]]
loop for chords** (observations → consistency mastery → live recommendations).

**Also done & on device:** [[Rhythm Mode]] — metronome + transition drill
(records transition/timing observations).

**Next (in order):**
1. **Recital mode** — deliberate assessment posture (vs. forgiving practice) that
   gates milestones with high-signal observations.
2. **Structured path** milestones reading coach mastery.
3. **Onboarding calibration** — seed the coach + guarantee a session-one "win".
4. **Timing calibration** — tune `inputLatency` so on-beat grading is accurate.

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
