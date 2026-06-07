# Strumbuddy — Design Document

> **Name.** "Strumbuddy" — the friendly, patient practice companion. Chosen for warmth and instant guitar-readability; verified clear on the App Store.

**Status:** v0.1 planning · living document
**Platform:** Native iOS (Swift / SwiftUI / AVFoundation + Accelerate)
**Last updated:** June 2026

---

## 1. Vision

Strumbuddy is an iOS app that listens to you play acoustic guitar and gives feedback at the quality a good human teacher would — not just "right note / wrong note," but *"your C is fine; it's specifically the change into it under tempo that's falling apart."* It is built around an **adaptive coach** that maintains a model of your individual skills, diagnoses your specific weak spots, and tells you what to work on next.

The core bet is that the durable advantage in this space is the **feedback engine**, not content. The incumbents' moat is content — filmed lesson curricula and licensed song catalogs — which is expensive to produce and maintain forever. We deliberately do not compete there. Our moat is code: an engine and a coaching model that scale for free and that no competitor does well.

### The real problem: retention

By Fender's own often-cited figure, roughly 90% of beginners quit within three months. So the product is really *retention*, and the feedback engine is in service of it. Every feature is judged by whether it keeps someone playing into month four. The adaptive coach is the centerpiece because personalized, explainable "here's your specific next step" is what sustains motivation when generic lesson plans don't.

---

## 2. Strategic positioning

### What we don't build
- **A filmed video curriculum.** JustinGuitar and Fender Play own this; producing it is a content treadmill a solo developer cannot win.
- **A licensed song catalog.** Gibson and others license artist tracks. We don't.

### Where we win
- **Tone and cleanliness feedback.** Yousician and similar tools are widely described as "mechanical" — they judge *whether* you hit the notes, not *how* you played them. Per-string clean-vs-muted-vs-buzzing feedback is the gap, and it falls almost for free out of our analysis (see §4).
- **Adaptive, explainable diagnosis.** A coach that watches you play and surfaces *your* specific weakness, with its reasoning shown, rather than a fixed lesson order or an opaque score.

Both differentiators are code, not content. That is the entire thesis.

---

## 3. Product structure: three modes, one engine

All three surfaces sit on top of a single shared capability — an engine that listens, identifies what was played, and grades it. They differ only in UI and intent.

1. **Structured path** — staged milestones the user checks off via a test (e.g., "play a clean G," "hold G→C at 60 bpm for eight bars"). Passing a milestone is just a threshold on the engine's scores; passing gates the next stage.
2. **Practice guides (the adaptive coach)** — the "work on…" surface. Driven by the skill model in §5. This is the heart of v0.1.
3. **Free play** — pick something and play, with scoring turned down or off. In v2 this becomes the home for bring-your-own-song.

Because the modes share the engine, most of the build cost is the engine and the coach; the modes themselves are thin presentation layers.

---

## 4. The audio engine

### Stack
Native iOS on AudioKit, capturing from `AVAudioEngine`'s input node. Two analysis taps run off the same microphone stream.

### Two-tap architecture
The critical constraint: **AudioKit's pitch tracking is monophonic** — `PitchTap` returns a single fundamental frequency, so it cannot identify a strummed chord on its own. The engine therefore splits:

- **Monophonic path** — `PitchTap` (or the Beethoven library) → single fundamental. Powers the tuner, single-note riffs, and melody work.
- **Polyphonic path** — FFT / Constant-Q Transform → chromagram (energy per pitch class) → chord-template matching (the Adam Stark approach). Powers chord identity.

The iOS app *Chordabra* is a working proof of this exact combination (AudioKit + CQT + Stark) and is a useful reference.

### Scoring rubric
Every observation is graded on four axes, which together feed both the milestone tests and the coach:

- **Accuracy** — were the right notes present?
- **Cleanliness** — did every expected string ring (vs. muted / dead / buzzing)?
- **Timing** — onset alignment against the metronome grid.
- **Consistency** — N good repetitions in a row.

Cleanliness is the differentiating axis and it comes from the chromagram for free: are all expected pitch classes present above threshold (clean), is an expected one missing (muted string), is there unexpected energy (buzz / wrong fret)? A black-box classifier would not hand us this, which is why the DSP chromagram is the backbone rather than a trained chord classifier.

### Simplifications and constraints
- **Constrained chord set.** The beginner path needs only ~8 open chords plus the F barre. Template-matching against just those shapes is far more accurate than general chord recognition. Build the detector we need, not a universal one.
- **Optional Core ML booster.** Apple's SoundAnalysis + a Create ML sound classifier can later improve *identity* robustness, but it can't produce cleanliness data, so it's an add-on, never the core.

### Licensing note (matters for commercial release)
Adam Stark's original chord-detection C++ is **GPL-3** — unacceptable for a sold product. Build the chromagram on Apple's **Accelerate / vDSP** (fast, first-party, no copyleft) and keep the polyphonic path entirely first-party Apple plus our own code. Verify the license of any third-party CQT dependency before adopting it.

---

## 5. The adaptive coach (heart of v0.1)

The coach is not one feature; it's three well-understood ideas stacked: **knowledge tracing** (infer hidden skill from noisy attempts), **spaced repetition** (skills decay; resurface them), and a **prerequisite graph** (skills depend on other skills). Four layers.

### 5.1 The skill graph
The atom is a **measurable micro-skill** — something the engine can produce evidence about: a chord shape, a strum pattern, a tempo hold, a fingerpicking figure.

The key design call: **transitions are first-class nodes, not edges.** A G→C change has its own mastery state, independent of G and C. You can know both chords cold and still fumble the change — and that fumble is exactly where beginners stall. Each transition node has prerequisite edges to its two chords.

The resulting prerequisite DAG does double duty: it gates what the coach may suggest (never recommend something whose prerequisites aren't met), and it explains *why* a user is stuck.

### 5.2 Mastery state with decay
Per skill, store not a boolean "done" but:
- a **proficiency** estimate,
- a **confidence** (a function of how many recent observations exist), and
- `last_practiced`.

Guitar is physical, so skill fades. Model each skill like an FSRS flashcard: *retrievability* ("can you play it clean right now") and *stability* ("how slowly it decays"). A skill nailed three weeks ago becomes due for review. **"Completed" is never permanent** — this is the piece most apps miss.

### 5.3 The evidence bridge and credit assignment
This is the magic. A single strummed G→C in a song is evidence about **five nodes at once**: the G, the C, the transition, the tempo hold, and the strum pattern. When it fails, which do we blame?

We disambiguate using the graph and the observation context:
- If standalone G and C are independently solid but the change fails under tempo → blame the **transition** node.
- If the C is shaky on its own → blame the **C**.

This is what lets the coach say *"your C is fine — it's specifically the change into it under time pressure,"* the diagnosis a human teacher gives and no competitor does. Consequently, **every observation must carry context** (tempo, isolated vs. in-song, which song), because a chord clean in isolation but muffed at speed is evidence about a *different* skill than the isolated chord.

### 5.4 The selection policy
"What should I work on" is a weighted pick over the graph, blending four signals:
- **Weakest-but-ready** — low proficiency with prerequisites satisfied (the zone of proximal development; never suggest the unattemptable).
- **Decay-due** — spaced-repetition resurfacing.
- **Goal-relevant** — a skill tied to something the user wants (in v2, a chord in a saved song: *"you want to play this; two of its chords are your weak spots"*).
- **Bottleneck leverage** — a weak prerequisite blocking many downstream skills (graph centrality).

Because every recommendation is graph-derived, the coach is **explainable** — it can show its reasoning instead of being an opaque score.

### 5.5 Data model
- **Append-only observation log.** Every attempt: timestamp, implicated skill IDs, context, per-axis scores.
- **Mastery state as a projection** over that log (event-sourcing / CDC pattern). This means inference can be re-tuned and replayed without losing history.
- **Storage.** On-device SQLite. The skill graph is small enough to live as a conceptual layer over relational tables — no graph database needed at this scale. Prerequisite traversal and centrality are cheap.
- **Cold start.** A short onboarding calibration seeds priors; the structured path drives early sessions; the coach takes over as observations accumulate and confidence rises.

---

## 6. v0.1 scope

**In:**
- The audio engine (both taps, four-axis scoring), tuned to the constrained beginner chord set.
- Tuner and metronome (cheap, and table stakes).
- The structured path with milestone tests.
- The adaptive coach: skill graph, mastery + decay, credit assignment, selection policy, observation log.
- Minimal onboarding calibration to seed the coach.

**Explicitly deferred:**
- **Bring-your-own-song and the chord simplifier / capo logic → v2.** (See §7.) This is the second headline feature but depends on an offline analysis pipeline and a clean engine first.
- LLM coach, passive "always-on" tracking, ear training, social features.
- Monetization wall (validate the core loop first).

**The v0.1 thesis to validate:** does engine-driven, explainable, adaptive coaching keep a beginner practicing longer than a generic lesson plan?

---

## 7. Roadmap

- **v0.1** — Engine + structured path + adaptive coach. (This document.)
- **v2** — Bring-your-own-song: analyze user-supplied audio (beat tracking + chord recognition over a full track), then the **chord simplifier** — vocabulary reduction plus capo placement that maps a song's real key onto easy open shapes, personalized to the user's known chords and rendered in difficulty tiers (Campfire / Standard / Full). Feeds directly into the coach as goal-relevant skills. *Licensing posture: chords only (no lyrics) over audio the user supplies, analyzed transiently on-device.*
- **Later** — LLM coach (dynamic, data-grounded explanations — leverages existing agent/LLM work), passive listening, ear training, premium tiers and monetization.

---

## 8. Open questions

- **Credit-assignment inference (§5.3)** — the exact mechanism by which blame propagates through the graph from one ambiguous observation. The hardest and most differentiating piece.
- **Selection-policy math (§5.4)** — how the four signals are weighted into one ranked list without the recommendations feeling repetitive.
- **Recognizability score (v2)** — how far the simplifier can strip a song before it stops being identifiable; turns the "recognizable, not perfect" goal into a tunable dial. Tabled for now.
- **Assessment UX** — how a milestone test decides "passed" without false negatives that trigger rage-quits. Lives inside the coach's scoring thresholds.
- **Curriculum authoring** — how the structured path's content gets produced without filming a course (likely LLM-assisted generation).
- **Monetization model** — freemium structure, where the paywall sits, trial design.
- **Onboarding / first five minutes** — the calibration flow and guaranteeing a "win" in session one.
