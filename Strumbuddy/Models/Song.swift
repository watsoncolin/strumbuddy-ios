import Foundation

/// A play-along song as a chord progression. **Chords only, no lyrics** — the
/// licensing-safe model (design-doc §7): chord progressions aren't copyrightable;
/// lyrics and recordings are. Each chord in a section lasts one bar. The built-in
/// library uses only the supported beginner chords; BYO-song arrives in v2.
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
    }

    /// Distinct chords used, in first-appearance order — for the "chords in this song" row.
    var allChords: [Chord] {
        var seen = Set<Chord>()
        return sections.flatMap(\.chords).filter { seen.insert($0).inserted }
    }

    /// The whole progression flattened to one chord per bar, for the play-along.
    var flatChords: [Chord] { sections.flatMap(\.chords) }

    // Public-domain / traditional songs only — see wiki: Licensing. Chord progressions
    // are not copyrightable and these compositions are out of copyright, so the built-in
    // library carries no licensing risk. Recognizable hits move to v2 bring-your-own-song.
    static let library: [Song] = [
        Song(id: 0, title: "Tom Dooley", artist: "Traditional", bpm: 90, sections: [
            Section(id: 0, name: "Verse", chords: [.g, .g, .d, .d, .d, .d, .g, .g]),
        ]),
        Song(id: 1, title: "When the Saints Go Marching In", artist: "Traditional", bpm: 100, sections: [
            Section(id: 0, name: "Verse", chords: [.g, .g, .c, .c, .g, .d, .g, .g]),
        ]),
        Song(id: 2, title: "Drunken Sailor", artist: "Traditional", bpm: 100, sections: [
            Section(id: 0, name: "Verse", chords: [.em, .em, .d, .d, .em, .em, .d, .em]),
        ]),
        Song(id: 3, title: "Swing Low, Sweet Chariot", artist: "Traditional", bpm: 72, sections: [
            Section(id: 0, name: "Chorus", chords: [.g, .c, .g, .d, .g, .c, .g, .g]),
        ]),
        Song(id: 4, title: "Oh! Susanna", artist: "Stephen Foster (1848)", bpm: 110, sections: [
            Section(id: 0, name: "Verse", chords: [.g, .g, .c, .g, .g, .d, .g, .g]),
        ]),
    ]
}
