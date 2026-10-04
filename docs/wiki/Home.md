---
tags: [strumbuddy, moc]
updated: 2026-10-04
---
# Strumbuddy — Wiki

Map of content for **Strumbuddy**: a native iOS coach that listens to acoustic
guitar and gives teacher-grade feedback. Repo: `strumbuddy-ios`. Deep design
rationale lives in the [design doc](../design-doc.md).

## Start here
- [[Vision and Strategy]] — what we're building and why
- [[Learning Philosophy]] — 0 → consistent practice; retention-first
- [[Daily Practice Loop]] — the keystone habit feature
- [[Architecture]] — three modes, one engine
- [[Roadmap]] — v0.1 scope and what's deferred
- [[BYO-Song (v2)]] — the v2 headline feature (scoping)

## The engine — built & working on device
- [[Audio Engine]]
    - [[Tuner]]
    - [[Chord Detection]]
    - [[Cleanliness Scoring]]
    - [[Muted-String Detection]]
- [[Rhythm Mode]] — metronome, transition drill, tempo ladder
- [[Chord Library]]
- [[Chord Preview]] — "Hear it": physically-modelled guitar strum

## The coach & the journey
- [[The Coach]] — mastery, credit assignment, diagnosis, placement
- [[Structured Path]] — 8-stage ladder
- [[Songs]] — graded play-along + goal song
- [[Progress]] — one-minute changes + progress screen
- [[Strumming]] — strum patterns: lessons + coach (**planned**)

## Reference
- [[Decisions]] — running decision log
- [[Glossary]]

## Status — October 2026
Engine validated on a real guitar and wired into [[The Coach]];
[[Daily Practice Loop]], onboarding and reminders live. October round (all built, harness-tested,
**not yet verified on device**): [[Chord Preview]], graded [[Songs]] with a goal
song, an 8-stage [[Structured Path]] + [[Rhythm Mode|tempo ladder]], the coach's
diagnosis after every run, [[Progress]] (one-minute changes + charts), and
onboarding placement. **Next:** device pass on the mic-driven flows; see [[Roadmap]].
