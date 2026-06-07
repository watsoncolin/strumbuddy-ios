---
tags: [strumbuddy, moc]
updated: 2026-06-07
---
# Strumbuddy — Wiki

Map of content for **Strumbuddy**: a native iOS coach that listens to acoustic
guitar and gives teacher-grade feedback. Repo: `strumbuddy-ios`. Deep design
rationale lives in the [design doc](../design-doc.md).

## Start here
- [[Vision and Strategy]] — what we're building and why
- [[Learning Philosophy]] — 0 → consistent practice; retention-first
- [[Daily Practice Loop]] — the keystone habit feature (next build)
- [[Architecture]] — three modes, one engine
- [[Roadmap]] — v0.1 scope and what's deferred
- [[BYO-Song (v2)]] — the v2 headline feature (scoping)

## The engine — built & working on device
- [[Audio Engine]]
    - [[Tuner]]
    - [[Chord Detection]]
    - [[Cleanliness Scoring]]
    - [[Muted-String Detection]]
- [[Rhythm Mode]] — metronome + transition drill
- [[Chord Library]]

## The coach — loop closed for chords
- [[The Coach]]

## Reference
- [[Decisions]] — running decision log
- [[Glossary]]

## Status — June 2026
Engine validated on a real guitar (tuner, chord identity, cleanliness, muted-string
detection) and wired into [[The Coach]]. [[Rhythm Mode]] (metronome + transition
drill) built. The **[[Daily Practice Loop]]** is now live — a "Today" home tab that
runs a coach-built session and tracks a streak. **Next:** first-session onboarding
(manufacture the session-one win), then the [[Structured Path]] as a ladder.
