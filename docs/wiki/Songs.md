---
tags: [strumbuddy, songs, retention]
updated: 2026-06-07
---
# Songs

The **motivation payoff** (see [[Learning Philosophy]] — "a real song ASAP"). A
Songs tab with built-in play-along songs. Status: **v1 built.**

## Model & licensing
`Song` = sections of **one chord per bar**, using only the supported [[Chord Library|chords]].
**Chords only, no lyrics, no recordings** — the licensing-safe model (design-doc §7):
chord progressions aren't copyrightable; lyrics/recordings are. Built-in library:
Tom Dooley (G/D, the 2-chord starter), Knockin' on Heaven's Door, Stand By Me,
Three Little Birds.

## Play-along
- `SongDetailView`: chord chart (chords-in-song diagrams + a per-section chip grid)
  plus a guided play-along.
- `SongPlayer` reuses the [[Rhythm Mode|metronome]] to advance one chord per bar,
  highlighting the current chord and showing what's next, looping. **No mic / no
  grading** — it guides you through the song; the payoff is just playing it.

## Future
- Per-chord grading along a song (reuse the engine) — currently guided only.
- v2: **bring-your-own-song** (analyze user audio → chords → capo simplifier), the
  headline differentiator (see [[Roadmap]]).
