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

    static let library: [Song] = [
        Song(id: 0, title: "Tom Dooley", artist: "Traditional", bpm: 90, sections: [
            Section(id: 0, name: "Verse", chords: [.g, .g, .d, .d, .d, .d, .g, .g]),
        ]),
        Song(id: 1, title: "Knockin' on Heaven's Door", artist: "Bob Dylan", bpm: 70, sections: [
            Section(id: 0, name: "Verse", chords: [.g, .d, .am, .am, .g, .d, .c, .c]),
        ]),
        Song(id: 2, title: "Stand By Me", artist: "Ben E. King", bpm: 118, sections: [
            Section(id: 0, name: "Verse", chords: [.g, .g, .em, .em, .c, .d, .g, .g]),
        ]),
        Song(id: 3, title: "Three Little Birds", artist: "Bob Marley", bpm: 75, sections: [
            Section(id: 0, name: "Chorus", chords: [.a, .a, .d, .a, .a, .e, .a, .a]),
        ]),
    ]
}
