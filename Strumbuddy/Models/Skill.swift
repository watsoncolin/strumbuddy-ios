import Foundation

/// A measurable micro-skill — something the engine can produce evidence about
/// (design-doc §5.1). The atom of the skill graph.
///
/// Design call: transitions (G→C) are FIRST-CLASS nodes, not edges. You can know
/// both chords cold and still fumble the change — and that fumble is where
/// beginners stall. A transition node has prerequisite edges to its two chords.
struct Skill: Identifiable, Codable, Hashable {
    let id: SkillID
    let kind: Kind
    /// IDs this skill depends on. The coach never suggests a skill whose
    /// prerequisites aren't yet met (zone of proximal development, §5.4).
    let prerequisites: [SkillID]

    enum Kind: Codable, Hashable {
        case chord(Chord)
        case transition(from: Chord, to: Chord)
        case strumPattern(name: String)
        case tempoHold(bpm: Int)
        case fingerpicking(name: String)
    }

    var displayName: String {
        switch kind {
        case .chord(let c):              return "\(c.displayName) chord"
        case .transition(let a, let b):  return "\(a.displayName) → \(b.displayName)"
        case .strumPattern(let n):       return "Strum: \(n)"
        case .tempoHold(let bpm):        return "Hold \(bpm) bpm"
        case .fingerpicking(let n):      return "Fingerpick: \(n)"
        }
    }
}

/// Stable string identifier so skills can key the observation log and SQLite rows.
struct SkillID: Hashable, Codable, RawRepresentable, CustomStringConvertible {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    var description: String { rawValue }

    static func chord(_ c: Chord) -> SkillID { .init(rawValue: "chord.\(c.rawValue)") }
    static func transition(from a: Chord, to b: Chord) -> SkillID {
        .init(rawValue: "transition.\(a.rawValue)-\(b.rawValue)")
    }
    static func tempoHold(_ bpm: Int) -> SkillID { .init(rawValue: "tempo.\(bpm)") }
    static func strum(_ name: String) -> SkillID { .init(rawValue: "strum.\(name)") }
}
