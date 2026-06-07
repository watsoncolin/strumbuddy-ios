# Strumbuddy

A warm, patient iOS coach for learning acoustic guitar. Strumbuddy listens to you
play and gives feedback at the quality of a good human teacher — not just
"right note / wrong note," but *"your C is fine; it's specifically the change into
it under tempo that's falling apart."*

The bet: the durable advantage here is the **feedback engine + adaptive coach**
(code we write once), not a filmed curriculum or licensed song catalog (a content
treadmill). The real product is **retention** — roughly 90% of beginners quit
within three months, and personalized, explainable coaching is what fights that.

See [`docs/design-doc.md`](docs/design-doc.md) for the full design.

## Architecture

Three modes, one engine (design-doc §3):

| Layer | What it is | Where |
|---|---|---|
| **Audio engine** | Mic capture + two analysis taps (monophonic pitch; polyphonic chromagram → chord ID + cleanliness), four-axis scoring | `Strumbuddy/Audio/` |
| **Adaptive coach** | Skill graph (transitions are first-class nodes), FSRS-style mastery+decay, credit assignment, selection policy, append-only observation log | `Strumbuddy/Coach/` |
| **Modes** | Structured Path · Practice (the coach) · Free Play (+ tuner) | `Strumbuddy/Features/` |

The four scoring axes — **accuracy, cleanliness, timing, consistency** — feed both
the structured-path milestone tests and the coach. Cleanliness is the
differentiator and falls out of the chromagram for free.

### No third-party dependencies (v0.1)

The audio engine is built on **AVFoundation + Accelerate/vDSP** (first-party, no
copyleft), per the design-doc §4 licensing note. AudioKit may be added later as an
optional convenience layer (commented block in `project.yml`).

## Build

Requires Xcode 26+. The project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen     # if needed
xcodegen generate         # regenerate Strumbuddy.xcodeproj from project.yml
open Strumbuddy.xcodeproj
```

Run on a **device** to use the microphone (the simulator has no real mic input).

## Status

v0.1 — engine + structured path + adaptive coach. Bring-your-own-song and the
chord simplifier are **v2** (design-doc §7). Open design questions — credit-assignment
inference and selection-policy weighting — are tracked in design-doc §8 and marked
with `OPEN QUESTION` in the code.
