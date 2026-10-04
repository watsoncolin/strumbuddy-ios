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

## Listen first
Hear the whole song before playing it: **Listen first** on the song screen strums it
at the selected speed (Practice/Full) with a one-bar click count-in, and outlines
the playing bar in the chart. Rendered by `Audio/SongRenderer.swift` from
[[Chord Preview]] strums (~150 ms per song) and played through `ChordPreviewPlayer`
(mic scoring paused). Starting Play along or leaving the screen stops it.
- **Pattern:** the beginner D · DU · UDU, accented downbeat, lighter ups; each new
  strum damps the last over 25 ms (the strumming hand); 3 seeded takes per
  chord/direction so repeats don't sound pasted.
- **Tested:** render length = count-in + bars + tail, and every bar of *When the
  Saints* reads as its chord at the moment the highlight shows it (8/8).
- Listen-only — not a backing track under the play-along (the mic would hear it;
  that would need headphones and different scoring). One pass of the 8-bar
  progression, ~20–30 s.

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
  bar grid, the coach's note ([[The Coach]]), and the **trickiest change** with a
  one-tap drill on exactly that change (opens at its [[Rhythm Mode|tempo-ladder]] rung).

## Goal song → the coach
`SongProgressStore` persists bests and the goal song, and feeds the song's chords +
changes to `Coach.setGoalSkills` — the goal-relevant signal in the selection policy
("it's in a song you want to play"). Goal skills only pull while unmastered.

## Future
- v2: **bring-your-own-song** (analyze user audio → chords → capo simplifier), the
  headline differentiator (see [[Roadmap]]).
