---
tags: [strumbuddy, coach, curriculum, audio, planned]
updated: 2026-10-04
---
# Strumming

Strum patterns as a taught, graded, coached skill. Status: **planned** — phase 1
(engine spike) in progress. Strumming was deliberately kept off the
[[Structured Path]] until the engine can grade it ([[Decisions]]).

## The basics we teach
- **The pendulum.** The strumming hand never stops: down on every beat (1 2 3 4), up
  on every "and". Count "1 & 2 & 3 & 4 &".
- **A pattern = which swings touch the strings.** Every 4/4 pattern lives on those 8
  slots. "D DU UDU" hits 1, 2, &, &, 4, & and *misses on purpose* on 3 — the hand
  still travels. Stopping the hand on the miss is the classic beginner failure.
- **Downs vs ups.** Downs start on the bass strings and sound fuller; ups catch the
  top strings, lighter. Accent falls on the downs.
- **The change trick.** On the "&" before a chord change, strum the open strings
  while the fretting hand moves — the fix for "I can't change in time" (links to
  [[Rhythm Mode|transitions]]).
- **Ladder:** one strum per bar → D D D D → D U D U D U D U → D DU D DU → D DU UDU
  ("Old Faithful", the pattern [[Songs#Listen first|Listen first]] plays).

## The engine gap (why phase 1 is a spike)
- **Onsets merge in continuous strumming.** Today's onset = RMS rising edge per
  4096-sample tap buffer (~93 ms). While you keep strumming, energy rarely dips
  below `playingRMS`, so consecutive strums aren't separated. Fine for "strum the
  chord," useless for patterns.
- **Direction is unknown.**

**Spike plan:**
1. Spectral-flux onset detection on 512-sample hops *inside* the existing 4096
   buffer (~11 ms resolution, no tap change). Pure type, harness-tested.
2. Down/up classifier from the first ~30 ms after an onset (low- vs high-band energy,
   centroid). Heuristic first.
3. Test audio: `GuitarSynth` renders labelled downs/ups for free (but is cleaner than
   reality); then real recordings, collected by lesson 1 itself ("8 downs… 8 ups").
4. **Decision gate:** direction < ~85% accurate on a real guitar → ship
   **rhythm-only grading** (direction taught and shown, not scored). A wrong "that
   was an up-strum" is worse than none.

## Lessons — "Strumming 101"
| Lesson | Focus | Graded on |
|---|---|---|
| 1 The pendulum | Count + move with the click, strings muted | Steady onsets (+ calibration data) |
| 2 Downs on the beat | D D D D on Em | Rhythm + cleanliness |
| 3 Add the ups | D U D U on Em | Rhythm (+ direction if gated in) |
| 4 The missed strum | D DU D DU, hand keeps moving | Rhythm, esp. no extra hits |
| 5 Old Faithful | D DU UDU | Rhythm |
| 6 Through changes | Pattern while G↔C, open-strum trick | Rhythm + transition |

Each lesson: **watch** (8-slot D/U grid; hand animation later) → **listen**
(`SongRenderer` with that pattern) → **try** (per slot: hit / correct miss / missed
hit / extra hit) → **coach's note** (pattern cases in `DrillDiagnosis`: "you're
stopping your hand on 3", "up-strums rushing", "falls apart at the change").

## Coach integration
- **Graph:** `SkillID.strum` / `.strumPattern` already exist, unused. Ladder:
  `strum.quarter → strum.eighths → strum.D-DU → strum.D-DU-UDU`.
- **Scoring into the existing axes** via a pure `PatternGrader` (expected slot times
  vs detected onsets): accuracy = pattern-match, timing = alignment, cleanliness =
  the chord. Mastery, [[Rhythm Mode|tempo ladder]] and [[Progress]] work unchanged.
- **Credit:** pattern on one held chord → the strum skill only; through a change →
  strum + transition + tempo. Strum skills join the "structural" group in
  `CreditAssignment`.
- **Path:** "Strum steady" after *Keep the beat*; "Your first pattern" after *Widen
  the vocabulary*; "Old Faithful through changes" before *Song speed*.
- **Daily session:** a pattern activity, so a weak pattern can be the Focus block.
- **Songs:** coach picks the hardest *mastered* pattern (fallback: one per bar), with
  a manual override; Listen plays the same pattern; play-along grades every stroke.

## Phases
1. Engine spike + gate. 2. Lessons 1–5 on one chord (grid first). 3. Coach: skills,
stages, daily blocks, diagnosis. 4. Songs + through changes (lesson 6). 5. Later:
accents, palm mutes, 3/4, swing.

## Decided (2026-10-04)
4/4 only for v1 (all built-in songs are 4/4) · grid before hand animation ·
coach-picked song pattern with override.

## Open questions
- Direction accuracy on real guitars — the gate above.
- Does continuous strumming break the current chord scoring (peak-hold finalizes on
  each onset)? Better onsets may change how many attempts Chord Check logs.
- Pattern + change failures: blame the pattern or the change? Needs the isolated
  pattern evidence first.
