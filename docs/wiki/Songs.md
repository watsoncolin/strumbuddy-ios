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
**Lyrics only where the words are public domain; no recordings** ([[Licensing]] has
the song-by-song check). Built-in library is **public-domain / traditional only**: Tom Dooley (G/D, the 2-chord starter), When the
Saints Go Marching In, Drunken Sailor (Em/D), Swing Low Sweet Chariot, Oh! Susanna.
Recognizable hits come via v2 bring-your-own-song, which stays chords-only — a
user's song's lyrics are someone else's copyright.

## Lyrics
`Song.Section.lyrics` — **line-level**: each line starts at a bar of its section.
That's how a beginner reads a chord chart, and it doesn't claim syllable timing we
haven't verified (a line can start up to a beat before its bar, where a song has a
pickup).
- Chart: one row of chord chips per lyric line, words underneath, so the Listen
  highlight follows the words.
- Play-along: the line being sung and the next line under the big chord; the first
  line during the count-in. `Song.lyrics(atBar:)` (tested) maps a song-wide bar to
  its line, across sections.
- Which songs have words: Saints, Drunken Sailor (verse, chorus, verse 2), Swing Low
  (chorus + "I looked over Jordan"), Oh! Susanna (verse 1 + chorus). **Tom Dooley is
  chords-only** — see [[Licensing]].
- Adding words fixed three charts: Saints is now the standard 16 bars
  (I I I I I I V V I I IV IV I V I I), Swing Low's second "carry me home" changes on
  D, Oh! Susanna has its 16-bar verse + chorus. Old bests on those were set on the
  previous charts.

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
