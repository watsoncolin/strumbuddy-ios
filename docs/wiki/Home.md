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
- [[Architecture]] — three modes, one engine
- [[Roadmap]] — v0.1 scope and what's deferred

## The engine — built & working on device
- [[Audio Engine]]
    - [[Tuner]]
    - [[Chord Detection]]
    - [[Cleanliness Scoring]]
    - [[Muted-String Detection]]
- [[Chord Library]]

## The coach — designed, not yet wired
- [[The Coach]]

## Reference
- [[Decisions]] — running decision log
- [[Glossary]]

## Status — June 2026
Engine validated on a real guitar: tuner, chord identity, per-note cleanliness,
and muted-string detection all working. **Next:** wire scored attempts into
[[The Coach]] as observations so it can actually learn and recommend.
