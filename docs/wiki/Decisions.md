---
tags: [strumbuddy, decisions]
updated: 2026-10-04
---
# Decisions

Running log of choices and *why*, newest first.

- **2026-10-04 — Onboarding placement is self-reported, but self-correcting.**
  Returning players tap known chords; each gets 3 just-clean (0.8) `.calibration`
  observations → mastered, so the path starts where they are. Trusting the claim is
  OK because seeded chords come due within days and mastery reads the last 4 real
  attempts (two fumbles un-master). Changes are never seeded. Implements the design
  doc's "calibration seeds priors". See [[The Coach]].
- **2026-10-04 — Untimed attempts leave timing out of the score.** Chord Check
  stored `timing = accuracy`, so the blended score double-counted accuracy and
  inflated mastery. `Observation.score` = (accuracy + cleanliness)/2 when there's no
  bpm. Mastery is a projection, so old logs re-score on replay.
- **2026-10-04 — Tempo evidence lands on graph hold levels.** Any drill/song at or
  above 60/80/100 bpm counts toward that hold (`TempoLadder.holdLevel`) instead of
  creating orphan `tempo.N` skills (songs at 65 bpm were never helping "hold 60").
- **2026-10-04 — Tempo ladder: +6 bpm once a change is clean.** Cleared = last 4
  attempts at that tempo average ≥ 0.75; ~10% steps feel achievable. See [[Rhythm Mode]].
- **2026-10-04 — Diagnosis blames chord vs. change using the coach's standalone
  belief** (≥ 0.7 → "the chord is solid, it's the change"), mirroring credit
  assignment — so the note and the mastery model agree. See [[The Coach]].
- **2026-10-04 — No strumming-pattern stage yet.** The engine can't grade strum
  patterns; a stage nobody can pass is worse than none.
- **2026-10-04 — Songs restored, graded, as a fifth tab.** June removed the
  guided-only tab as deferred; songs are the "real song ASAP" payoff, and grading
  reuses `DrillSession` (fixed sequence) rather than a second grader. Goal skills
  only pull while unmastered. See [[Songs]].
- **2026-10-04 — Chord preview by physical modelling, not samples or additive.**
  The additive synth sounded like an organ; recorded samples raise licensing/asset
  questions; Karplus-Strong with real voicings is dependency-free and testable.
  Sound was tuned by *physics* (triangle pluck, bridge-force derivative), with our
  own tuner/detector as checks — not by fitting the detector. See [[Chord Preview]].
- **2026-10-04 — The app pauses its own ears while it makes sound.**
  `AudioEngine.suppressInput` during previews, so "Hear it" can't count as a strum.
- **Retention-first reprioritization.** Next build is the habit engine
  ([[Daily Practice Loop]] + first-win onboarding), not more teaching — the thesis is
  retention (~90% quit) and the behavior layer is under-built. Grounded in
  [[Learning Philosophy]].
- **Recital mode dropped.** Consistency-based practice grading already covers
  "demonstrate it reliably"; a separate high-stakes assessment isn't worth it for v0.1.
- **Drill timing via peak-hold landing + a latency constant.** Timing is graded from
  when the bar's best strum landed (`targetScoreTime`) vs the beat, with a fixed
  `inputLatency` (~0.09s) approximating capture latency. Coarse but cheap and
  calibratable; avoids fragile real-time onset detection. See [[Rhythm Mode]].
- **Metronome click in a separate audio engine.** The click runs on its own
  `AVAudioPlayerNode`; bleed into the mic is harmless because grading keys off
  detected chords, not raw onsets.
- **Consistency-based mastery, not last-attempt.** The coach masters a skill on ≥3
  of the last 4 clean attempts, with a gentle EMA (0.3) for proficiency — so a fumble
  doesn't undo progress and a lucky strum doesn't earn mastery. Matches how a teacher
  judges ("reliable, not perfect, not once"). See [[The Coach]].
- **One observation per strum.** The peak-hold smoother emits a `finalized` best when
  a strum ends; that single attempt is what's recorded — not every frame.
- **Recital mode as a separate assessment posture.** Practice is forgiving/continuous;
  recital is deliberate and gates milestones with high-signal observations. Same engine,
  different `Observation.Context.source`.
- **Wiki in the repo as an Obsidian vault** (`docs/wiki/`) — knowledge travels with
  the code, version-controlled. Pair with `kepano/obsidian-skills` for idiomatic edits.
- **Muted-string detection via raw spectrum** — expose FFT magnitudes (already
  computed) to catch a ringing muted string by its fundamental frequency, since the
  octave-folded chroma can't. See [[Muted-String Detection]].
- **Peak-hold over EMA for chord scoring** — reward the cleanest instant of a strum
  rather than punishing natural decay; honest because a real mute never rings. See
  [[Cleanliness Scoring]].
- **AI hand images rejected** — explored Runware (FLUX, then Nano Banana / Gemini
  `google:4@1`). POV shots looked great but **none render correct fingerings**, and
  a wrong hand is worse than none. The deterministic [[Chord Library|chord diagram]]
  is the instructional source of truth. Image gen can't be trusted for *correctness*.
- **Hand-rolled chromagram on Accelerate/vDSP** — avoids Adam Stark's GPL-3 chord
  code; keeps v0.1 **dependency-free** and the DSP cores pure/testable.
- **Pure DSP cores, tested off-device** — `scripts/main.swift` compiles the pure
  types and asserts behavior on synthesized tones (no simulator runtime needed).
- **Name: Strumbuddy** — warm + guitar-obvious; chosen over the working title
  "Woodshed"; verified clear on the App Store.
- **Native `/voice` for dictation** — Claude Code's built-in voice (v2.1.69+),
  coding-tuned; no third-party Whisper app needed.

## Tuning constants (current)
`presenceThreshold 0.28` · `buzzThreshold 0.5` · `mutedRingThreshold 0.3` ·
`playingRMS 0.006` · `minClarity 0.5` · `PitchDetector.minRMS 0.003`. All dialed by
ear on device.

Added 2026-10 (not yet tuned on device): **tempo ladder** start 60 · step 6 · ceiling
160 · window 4 · clear 0.75 · hold levels 60/80/100. **Diagnosis** clean bar 0.75 ·
off-beat 0.08 s · solid chord 0.7. **Songs** practice tempo ≈70% (min 50, nearest 5)
· stars ≥0.85/0.7/0.5. **One-minute** landing ≥0.6 accuracy. **Placement** 3 × 0.8.
**GuitarSynth** pick 0.12 · high-pass 110 Hz · strum spread 13 ms.
