---
tags: [strumbuddy, songs, retention]
updated: 2026-10-04
---
# Songs

The **motivation payoff** (see [[Learning Philosophy]] — "a real song ASAP"). A
Songs tab with built-in play-along songs, **graded bar by bar**. Status: **v2 built**
(the v1 guided-only tab was removed in the daily check-in revamp, then restored with
grading).

## Model & licensing
`Song` = sections of **one chord per bar**, using only the supported [[Chord Library|chords]].
**Chords only, no lyrics, no recordings** ([[Licensing]]). Built-in library is
**public-domain / traditional only**: Tom Dooley (G/D, the 2-chord starter), When the
Saints Go Marching In, Drunken Sailor (Em/D), Swing Low Sweet Chariot, Oh! Susanna.
Recognizable hits come via v2 bring-your-own-song.

## Play-along (graded)
- `SongsView`: list with best stars and readiness ("Ready" when every chord is
  mastered, else which chords you're still learning). The goal song is pinned on top.
- `SongDetailView`: chord cards (diagram + mastered check + "Hear it" preview), a
  per-section bar grid, Practice (~70% tempo) / Full speed, and **Make this my goal**.
- The play-along runs on `DrillSession` with the song as a `fixedSequence`: count-in,
  then one chord per bar, each bar graded (accuracy + cleanliness + timing) and logged
  to [[The Coach]] with source `.song`, `inSequence`. A held chord (G→G) is evidence
  about the chord only, not a "change".
- Summary (`SongReport`, pure + tested): score, 0–3 stars, personal best, the graded
  bar grid, and the **trickiest change** with a one-tap drill on exactly that change.

## Goal song → the coach
`SongProgressStore` persists bests and the goal song, and feeds the song's chords +
changes to `Coach.setGoalSkills` — the goal-relevant signal in the selection policy
("it's in a song you want to play"). Goal skills only pull while unmastered.

## Future
- v2: **bring-your-own-song** (analyze user audio → chords → capo simplifier), the
  headline differentiator (see [[Roadmap]]).
