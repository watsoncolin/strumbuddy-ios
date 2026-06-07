import Foundation

/// A beginner tip/hint. Surfaced as a rotating daily card and a browsable list.
/// Heavy on the early physical struggle (sore fingers) — the #1 quiet quit reason
/// (see wiki: Learning Philosophy).
struct Tip: Identifiable {
    let id: Int
    let category: Category
    let icon: String      // SF Symbol
    let title: String
    let body: String
    /// Lets a tip be surfaced contextually when the engine detects that problem.
    var key: HintKey? = nil

    enum Category: String, CaseIterable {
        case comfort = "Comfort & hands"
        case technique = "Technique"
        case mindset = "Mindset"
    }

    /// Conditions a tip can answer, for contextual hints.
    enum HintKey { case buzzing, deadString, muteSkipped, soreFingers, stuckChange }

    static let library: [Tip] = [
        Tip(id: 0, category: .comfort, icon: "hand.raised",
            title: "Sore fingertips are normal",
            body: "Tender tips are just week one. Calluses form in about two to three weeks and the soreness fades. Short daily sessions build them faster — and gentler — than rare long ones."),
        Tip(id: 1, category: .comfort, icon: "timer",
            title: "Stop before it hurts",
            body: "Don't push through real pain. Five to ten focused minutes a day beats one long painful session — better for your fingers and for the habit.",
            key: .soreFingers),
        Tip(id: 2, category: .comfort, icon: "hand.point.up.left",
            title: "Press with your fingertips",
            body: "Curl your fingers and press with the very tips, not the flat pads. It takes less force and leaves the neighbouring strings free to ring."),
        Tip(id: 3, category: .comfort, icon: "hand.draw",
            title: "Relax your thumb",
            body: "Rest your thumb behind the neck — roughly behind your middle finger — not wrapped over the top. A loose grip reaches further and cramps less."),
        Tip(id: 4, category: .technique, icon: "ruler",
            title: "Press just behind the fret",
            body: "Fret right behind the metal fret wire, not on top of it or back in the gap. You'll need far less pressure and get far less buzz."),
        Tip(id: 5, category: .technique, icon: "waveform.path",
            title: "Buzzing? Two quick fixes",
            body: "A buzzing string usually means press a touch firmer, or slide your finger closer behind the fret. Clean notes come from placement, not brute force.",
            key: .buzzing),
        Tip(id: 6, category: .technique, icon: "circle.dashed",
            title: "Dead string? Arch your fingers",
            body: "If a string goes silent, a finger is probably leaning on it. Arch your knuckles so each fingertip lands straight down on its own string.",
            key: .deadString),
        Tip(id: 7, category: .technique, icon: "arrow.triangle.2.circlepath",
            title: "Practise changes silently",
            body: "Stuck on a chord change? Switch between the two shapes slowly without strumming, watching your fingers. Speed comes once the shape is automatic.",
            key: .stuckChange),
        Tip(id: 10, category: .technique, icon: "speaker.slash",
            title: "Mute the strings you skip",
            body: "Chords like C and D don't use every string. Rest a fingertip lightly against the ones you skip so they stay quiet instead of booming.",
            key: .muteSkipped),
        Tip(id: 8, category: .mindset, icon: "heart",
            title: "Everyone's first chords buzz",
            body: "Sounding rough at the start is universal — it's not a sign you can't do this. Aim for a little better than yesterday, not perfect."),
        Tip(id: 9, category: .mindset, icon: "flame",
            title: "Consistency beats marathons",
            body: "Ten minutes every day takes you further than two hours once a week. Keep the streak alive and let the calluses and muscle memory build."),
    ]

    /// The tip for a given day-ordinal — rotates daily, stable within a day.
    static func daily(day: Int) -> Tip {
        let count = library.count
        return library[((day % count) + count) % count]
    }

    /// The tip answering a specific condition, if one exists.
    static func forHint(_ key: HintKey) -> Tip? {
        library.first { $0.key == key }
    }

    /// Pick the most relevant contextual hint for a graded attempt. Priority matches
    /// the Chord Check feedback: ringing muted string → dead expected note → buzz.
    static func contextualHint(hasRingingMuted: Bool, hasMuted: Bool, hasBuzzing: Bool) -> Tip? {
        if hasRingingMuted { return forHint(.muteSkipped) }
        if hasMuted        { return forHint(.deadString) }
        if hasBuzzing      { return forHint(.buzzing) }
        return nil
    }
}
