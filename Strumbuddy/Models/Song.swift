import Foundation

/// A play-along song as a chord progression, with lyrics where they're public domain.
/// Each chord in a section lasts one bar. The built-in library uses only the
/// supported beginner chords; BYO-song (design-doc §7) stays chords-only, since a
/// user's song's lyrics are someone else's copyright.
struct Song: Identifiable {
    let id: Int
    let title: String
    let artist: String
    let bpm: Int
    let sections: [Section]

    struct Section: Identifiable {
        let id: Int
        let name: String
        let chords: [Chord]   // one chord per bar
        /// Lyric lines, each starting at a bar of this section (0-based). Line-level,
        /// not word-level: how a beginner reads a chord chart, and it doesn't claim
        /// syllable timing we haven't verified. Empty when the words aren't free to use.
        var lyrics: [Lyric] = []
    }

    struct Lyric: Equatable {
        let bar: Int
        let text: String
    }

    /// Distinct chords used, in first-appearance order — for the "chords in this song" row.
    var allChords: [Chord] {
        var seen = Set<Chord>()
        return sections.flatMap(\.chords).filter { seen.insert($0).inserted }
    }

    /// The whole progression flattened to one chord per bar, for the play-along.
    var flatChords: [Chord] { sections.flatMap(\.chords) }

    var hasLyrics: Bool { sections.contains { !$0.lyrics.isEmpty } }

    /// The lyric line being sung at a song-wide bar index, and the one after it —
    /// for the play-along and "Listen" readouts.
    func lyrics(atBar bar: Int) -> (current: String?, next: String?) {
        var lines: [(bar: Int, text: String)] = []
        var offset = 0
        for section in sections {
            lines += section.lyrics.map { (offset + $0.bar, $0.text) }
            offset += section.chords.count
        }
        guard let i = lines.lastIndex(where: { $0.bar <= bar }) else {
            return (nil, lines.first?.text)
        }
        return (lines[i].text, i + 1 < lines.count ? lines[i + 1].text : nil)
    }

    // Public-domain / traditional songs only — see wiki: Licensing. Chord progressions
    // aren't copyrightable and these compositions are out of copyright. Lyrics are
    // included only where the words themselves are public domain:
    //  • Tom Dooley — chords only. The tune is traditional, but the familiar words are
    //    the 1947 Warner/Lomax "collected, adapted and arranged" copyright, enforced
    //    after the Kingston Trio's 1958 hit.
    //  • Oh! Susanna — Foster's verse 1 + chorus in standard spelling; his original
    //    second verse contains a racial slur and is deliberately left out.
    // Recognizable hits move to v2 bring-your-own-song (chords only).
    static let library: [Song] = [
        Song(id: 0, title: "Tom Dooley", artist: "Traditional", bpm: 90, sections: [
            Section(id: 0, name: "Verse", chords: [.g, .g, .d, .d, .d, .d, .g, .g]),
        ]),
        Song(id: 1, title: "When the Saints Go Marching In", artist: "Traditional spiritual", bpm: 100, sections: [
            Section(id: 0, name: "Verse",
                    chords: [.g, .g, .g, .g, .g, .g, .d, .d, .g, .g, .c, .c, .g, .d, .g, .g],
                    lyrics: [
                        Lyric(bar: 0, text: "Oh, when the saints go marching in,"),
                        Lyric(bar: 4, text: "Oh, when the saints go marching in,"),
                        Lyric(bar: 8, text: "Oh Lord, I want to be in that number,"),
                        Lyric(bar: 12, text: "When the saints go marching in."),
                    ]),
        ]),
        Song(id: 2, title: "Drunken Sailor", artist: "Traditional sea shanty", bpm: 100, sections: [
            Section(id: 0, name: "Verse", chords: [.em, .em, .d, .d, .em, .em, .d, .em],
                    lyrics: [
                        Lyric(bar: 0, text: "What shall we do with a drunken sailor?"),
                        Lyric(bar: 2, text: "What shall we do with a drunken sailor?"),
                        Lyric(bar: 4, text: "What shall we do with a drunken sailor,"),
                        Lyric(bar: 6, text: "Early in the morning?"),
                    ]),
            Section(id: 1, name: "Chorus", chords: [.em, .em, .d, .d, .em, .em, .d, .em],
                    lyrics: [
                        Lyric(bar: 0, text: "Way hay and up she rises,"),
                        Lyric(bar: 2, text: "Way hay and up she rises,"),
                        Lyric(bar: 4, text: "Way hay and up she rises,"),
                        Lyric(bar: 6, text: "Early in the morning."),
                    ]),
            Section(id: 2, name: "Verse 2", chords: [.em, .em, .d, .d, .em, .em, .d, .em],
                    lyrics: [
                        Lyric(bar: 0, text: "Put him in the longboat till he's sober,"),
                        Lyric(bar: 2, text: "Put him in the longboat till he's sober,"),
                        Lyric(bar: 4, text: "Put him in the longboat till he's sober,"),
                        Lyric(bar: 6, text: "Early in the morning."),
                    ]),
        ]),
        Song(id: 3, title: "Swing Low, Sweet Chariot", artist: "Wallace Willis (before 1862)", bpm: 72, sections: [
            Section(id: 0, name: "Chorus", chords: [.g, .c, .g, .d, .g, .c, .d, .g],
                    lyrics: [
                        Lyric(bar: 0, text: "Swing low, sweet chariot,"),
                        Lyric(bar: 2, text: "Comin' for to carry me home."),
                        Lyric(bar: 4, text: "Swing low, sweet chariot,"),
                        Lyric(bar: 6, text: "Comin' for to carry me home."),
                    ]),
            Section(id: 1, name: "Verse", chords: [.g, .c, .g, .d, .g, .c, .d, .g],
                    lyrics: [
                        Lyric(bar: 0, text: "I looked over Jordan, and what did I see,"),
                        Lyric(bar: 2, text: "Comin' for to carry me home?"),
                        Lyric(bar: 4, text: "A band of angels comin' after me,"),
                        Lyric(bar: 6, text: "Comin' for to carry me home."),
                    ]),
        ]),
        Song(id: 4, title: "Oh! Susanna", artist: "Stephen Foster (1848)", bpm: 110, sections: [
            Section(id: 0, name: "Verse",
                    chords: [.g, .g, .g, .d, .g, .g, .d, .g, .g, .g, .g, .d, .g, .g, .d, .g],
                    lyrics: [
                        Lyric(bar: 0, text: "I came from Alabama with a banjo on my knee,"),
                        Lyric(bar: 4, text: "I'm going to Louisiana, my true love for to see."),
                        Lyric(bar: 8, text: "It rained all night the day I left, the weather it was dry,"),
                        Lyric(bar: 12, text: "The sun so hot I froze to death; Susanna, don't you cry."),
                    ]),
            Section(id: 1, name: "Chorus", chords: [.c, .c, .g, .d, .g, .g, .d, .g],
                    lyrics: [
                        Lyric(bar: 0, text: "Oh! Susanna, oh don't you cry for me,"),
                        Lyric(bar: 4, text: "For I came from Alabama with a banjo on my knee."),
                    ]),
        ]),
    ]
}
