---
tags: [strumbuddy, strategy, legal]
updated: 2026-10-04
---
# Licensing

> Not legal advice. Get an IP lawyer's read before a commercial launch involving any
> non-public-domain songs.

How copyright shapes what Strumbuddy can ship — and why we keep content thin (the
moat is the engine, not a catalog; see [[Vision and Strategy]]).

## What's protected vs not
A song has two copyrights: the **composition** (melody + lyrics, songwriter/publisher)
and the **sound recording** (the master, label).
- **Lyrics, melody/TAB, recordings, album art** — protected. ❌ Never ship without a license.
- **Chord progressions** — generally *not* copyrightable; a bare chord chart sits in a
  tolerated **gray zone**. ⚠️ Publishers (NMPA) have still asserted rights against tab
  sites; the big ones operate under publisher licenses (e.g. Chordify ↔ LyricFind).
- **Song titles / artist names** — not copyrightable; fine to reference. ✅

## Decisions
- **Content rule:** chords, plus **lyrics only where the words themselves are
  public domain**. Still no melody/TAB, no copyrighted recordings, no art. The
  only audio we ship is our own synthesized strumming ([[Chord Preview]],
  [[Songs#Listen first|Listen first]]), not a recording of anyone's performance.
  *(Was "chords only, no lyrics" until 2026-10-04; see [[Decisions]].)*
- **Built-in [[Songs]] are public-domain / traditional only** (Tom Dooley, When the
  Saints, Drunken Sailor, Swing Low, Oh! Susanna). Compositions out of copyright +
  uncopyrightable chord charts = no licensing risk. (We dropped the earlier
  copyrighted picks — Knockin'/Stand By Me/Three Little Birds.)
- **Lyrics, song by song** (checked 2026-10-04):
  - ✅ *When the Saints Go Marching In* — traditional spiritual.
  - ✅ *Drunken Sailor* — traditional sea shanty.
  - ✅ *Swing Low, Sweet Chariot* — Wallace Willis, before 1862.
  - ✅ *Oh! Susanna* — Stephen Foster, 1848: **verse 1 + chorus only**, in standard
    spelling. Foster's second verse contains a racial slur and is left out on
    purpose (a content call, not a copyright one).
  - ❌ *Tom Dooley* — **chords only.** The tune is traditional, but the familiar
    words are the 1947 Warner/Lomax "collected, adapted and arranged" copyright,
    enforced after the Kingston Trio's 1958 hit.
  - Rule for new songs: a public-domain *composition* doesn't make every *version*
    of its words free. Check which text you're using before adding lyrics.
- **Recognizable hits come via v2 [[Roadmap|bring-your-own-song]]:** the user analyzes
  *their own* audio, transiently, on-device, chords-only — so we never distribute a
  catalog. This is the design-doc §7 strategy.

## If we ever want named hits in-app
Options, in rough order of effort: license chord/lyric data via an aggregator
(LyricFind / Musixmatch) or publishers; or stay PD + BYO. Avoid shipping a curated
copyrighted catalog without licenses.
