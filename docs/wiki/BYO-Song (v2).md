---
tags: [strumbuddy, v2, design, songs]
updated: 2026-06-07
---
# Bring-Your-Own-Song (v2)

The second headline feature (design-doc §7): point Strumbuddy at a song *you* want to
learn; it works out the chords and coaches you through a beginner-friendly version.
Status: **scoping.** The differentiator that an unbounded "play the song stuck in
your head" library gives — without a licensed catalog ([[Licensing]]).

## User story
"Help me play this song" → import audio you own (or play it near the device) →
Strumbuddy analyses it → a **simplified, capo-ready chord chart** in a difficulty
tier you choose → play along with the [[Songs|guided player]], and its chords feed
[[The Coach]] as goal-relevant skills.

## Legal posture (settled — [[Licensing]])
Analyse **user-supplied audio, transiently, on-device. Chords only.** No lyrics, no
redistributed catalog, no scraping streaming services. Sourcing = the legal firewall.

## The pipeline
1. **Input / decode** — read a user audio file (AVAudioFile) or capture playback.
2. **Beat & tempo tracking** — onset/spectral-flux → tempo → a beat grid.
3. **Chord recognition over time** — per-beat chroma → chord classification over a
   *full* vocabulary (maj/min/7th × 12 roots) → temporal smoothing (HMM/Viterbi) →
   a chord timeline. **This is the hard part** (see Risks).
4. **Key detection** — Krumhansl-Schmuckler profiles over the overall chroma.
5. **Simplification** — vocabulary reduction + **capo placement** → difficulty tiers.
6. **Present & coach** — timed play-along; chords become goal-relevant coach skills.

## What we reuse from v0.1
- **Chromagram** (vDSP) — the analysis primitive; run offline over a track instead of live.
- **Chord templates / detection** — extend from the 8-chord set to the full vocabulary.
- **Song play-along UI** — generalize from fixed bars to a timed chord timeline.
- **The coach + drill** — BYO chords slot in as skills; transitions/timing for free.
- **Capo/key math** — pure, testable, builds on `Chord`/`ChordShape`.

## The simplifier (the differentiator within v2) — pure & buildable now
From one detected timeline, produce tiers:
- **Vocabulary reduction**: strip extensions (Fmaj7→F), drop slash bass; never change
  major↔minor (that destroys the song). Bound to the user's known chords.
- **Capo placement**: a capo lets you play the song's real key with easy open shapes
  from another key. Modular-arithmetic on semitones: for each capo fret 0–7, compute
  the shape-key, score by how many chords (weighted by frequency) become easy open
  shapes, penalise barres; pick the best. **Personalised** to the user's known chords.
- **Difficulty tiers**: Campfire (3–4 open chords + capo) / Standard (real chords, no
  extensions) / Full (exact). Ladders a loved song to the user's level.

## Risks & unknowns
- **Chord recognition accuracy on full mixes** is the load-bearing risk — drums,
  vocals, bass make it much harder than solo guitar (~75–85% even for good systems).
  Mitigation: target sparse/slow songs first; let the user **correct** mistakes
  (correction data is gold); be honest about accuracy in the UI.
- **Libraries are mostly GPL/AGPL or Python** (aubio, Chordino, Essentia) — conflicts
  with our dependency-free/commercial stance. Likely **roll our own on Accelerate**,
  possibly a **Core ML** chord model. (Spotify `basic-pitch`, Apache-2, is a reference
  for the melodic/transcription path.)
- **Harmonic vs melodic**: some songs live in a riff, not chords. Detect and route
  riff songs to the monophonic riff trainer (the [[Tuner|monophonic path]]).
- **Recognizability score** (design-doc §8) — how far we can strip a song before it
  stops being identifiable. Turns "recognizable, not perfect" into a tunable dial.

## Phasing
- **v2.0** — import a file → beat + chord timeline → timed play-along (chords only,
  on-device). Accept moderate accuracy + manual correction.
- **v2.1** — the **simplifier**: capo + vocabulary reduction + difficulty tiers,
  personalised to known chords. (High value, mostly pure.)
- **v2.2** — harmonic-vs-melodic routing; riff trainer.
- **v2.3** — coach integration (goal-relevant skills) + premium gating of analysis
  (compute cost meters naturally into a subscription).

## Progress
- ✅ **Chord-recognition spike** (`ChordRecognizer`, pure & harness-tested): window
  audio → chroma frames → cosine-match 24 maj/min templates → self-transition Viterbi
  → chord timeline. On a synthesized C→G→Am→F it recovers **100%**, distinguishing Am
  from A major. **Finding:** the algorithm is sound on *clean* input (upper bound).
  The real unknown — accuracy on full mixes (drums/vocals/bass) — still needs **real
  recordings on a device** to measure. That's the gate before committing to v2.0.
- ✅ **Capo simplifier** (`CapoSimplifier` + `ChordSymbol`, pure): best capo for easy
  open shapes, personalizable to known shapes.
- ✅ **Difficulty tiers** (`SongSimplifier`, pure): full / capo / campfire. Campfire
  substitutes any un-cappable chord with the nearest easy open chord (vocabulary
  reduction). Wired into the Analyze results as a Campfire/Capo/Full picker.
- ✅ **Synth-guitar reconstruction** (`ChordSynth` + `SynthPlayer`): play the song
  back as strummed synth guitar ("Hear it" on the Analyze results). **Tier-aware** —
  plays the selected tier's actual sounding chords (`SongSimplifier.soundingChords`)
  and **loops** as a backing track. Efficient overlap-add render. Pure, harness-tested.

- ✅ **Device analyze harness** (`AnalyzeView`, Songs tab → "Analyze your own song
  (beta)"): three input paths — **pick a file** (`AudioFileLoader`, first 90s),
  **Listen** via mic (`AudioRecorder`, play a song near the phone, capped 40s), and
  bundled **demo files**. All run decode/record → `ChordRecognizer` → timeline + capo.
  Demos verified (C·G·Am·F → capo 5 → G·D·Em·C; Em·D and G·C·D → no capo). This is the
  **gate experiment** for v2.0 — run Listen/file on real audio to measure real-mix accuracy.

## Recommended next steps
1. **Run the analyze harness on real recordings** (on device) and judge accuracy.
   That decision gates whether v2.0 ships as designed or needs a stronger recognizer
   (e.g. a Core ML chord model).
2. Vocabulary reduction + difficulty tiers (pure, builds on the simplifier).
