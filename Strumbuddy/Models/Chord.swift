import Foundation

/// One of the twelve pitch classes (C, C#, … B). The chromagram measures energy
/// per pitch class; chords are matched as sets of expected pitch classes.
enum PitchClass: Int, CaseIterable, Codable, Hashable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    var name: String {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][rawValue]
    }
}

/// The constrained beginner chord set (design-doc §4 "Constrained chord set").
///
/// We intentionally support only the ~8 open chords plus the F barre rather than a
/// universal recognizer — template-matching a tiny fixed set is far more accurate.
enum Chord: String, CaseIterable, Codable, Identifiable, Hashable {
    case e = "E"
    case em = "Em"
    case a = "A"
    case am = "Am"
    case d = "D"
    case g = "G"
    case c = "C"
    case f = "F"   // first barre chord — the beginner wall

    var id: String { rawValue }

    var displayName: String { rawValue }

    var isBarre: Bool { self == .f }

    /// The pitch classes that should ring in a clean voicing. Used both as the
    /// chromagram match template and as the "expected notes" for cleanliness
    /// grading (which strings are missing / extra).
    var expectedPitchClasses: Set<PitchClass> {
        switch self {
        case .e:  return [.e, .gSharp, .b]
        case .em: return [.e, .g, .b]
        case .a:  return [.a, .cSharp, .e]
        case .am: return [.a, .c, .e]
        case .d:  return [.d, .fSharp, .a]
        case .g:  return [.g, .b, .d]
        case .c:  return [.c, .e, .g]
        case .f:  return [.f, .a, .c]
        }
    }
}
