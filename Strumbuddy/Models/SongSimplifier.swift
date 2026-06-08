import Foundation

/// Difficulty tiers for a song's chords (design-doc §7), building on `CapoSimplifier`.
/// Ladders a loved song from exact to dead-easy:
///   • full     — the exact chords, no capo (needs barres).
///   • capo     — same chords, fingered as open shapes with the best capo.
///   • campfire — capo *plus* substitute any still-hard chord with the nearest easy
///                open chord, so every chord is beginner-playable (recognizable,
///                not exact — "play the song you love at your level").
enum DifficultyTier: String, CaseIterable, Identifiable, Hashable {
    case campfire = "Campfire"
    case capo = "Capo"
    case full = "Full"

    var id: String { rawValue }
    var blurb: String {
        switch self {
        case .campfire: return "All easy open chords — recognizable, not exact."
        case .capo:     return "Same chords, easy open shapes with a capo."
        case .full:     return "The exact chords."
        }
    }
}

/// One arrangement of a song's (unique) chords at a chosen tier.
struct SongArrangement: Equatable {
    let tier: DifficultyTier
    let capo: Int
    /// The shape to finger for each input chord, in order.
    let shapes: [ChordSymbol]
    /// Fraction of shapes that are easy open chords.
    let coverage: Double
}

struct SongSimplifier {
    var maxFret = 7
    var easyShapes: Set<ChordSymbol> = ChordSymbol.openShapes

    /// `chords` should be the song's unique chord vocabulary.
    func arrange(_ chords: [ChordSymbol], tier: DifficultyTier) -> SongArrangement {
        switch tier {
        case .full:
            let easy = chords.filter { easyShapes.contains($0) }.count
            return SongArrangement(tier: .full, capo: 0, shapes: chords,
                                   coverage: chords.isEmpty ? 0 : Double(easy) / Double(chords.count))

        case .capo:
            let s = CapoSimplifier(maxFret: maxFret, easyShapes: easyShapes).suggest(for: chords)
            return SongArrangement(tier: .capo, capo: s.capo, shapes: s.shapes, coverage: s.coverage)

        case .campfire:
            let s = CapoSimplifier(maxFret: maxFret, easyShapes: easyShapes).suggest(for: chords)
            let subbed = s.shapes.map { easyShapes.contains($0) ? $0 : nearestEasy($0) }
            return SongArrangement(tier: .campfire, capo: s.capo, shapes: subbed,
                                   coverage: chords.isEmpty ? 0 : 1.0)
        }
    }

    /// What each input chord actually SOUNDS as in this tier's arrangement. A capo
    /// shifts the fingered shape back up to concert pitch, so full/capo sound the same
    /// as the detected chords; campfire substitutions genuinely change the harmony.
    /// Used for tier-aware playback.
    func soundingChords(_ chords: [ChordSymbol], tier: DifficultyTier) -> [ChordSymbol] {
        let arrangement = arrange(chords, tier: tier)
        return arrangement.shapes.map {
            ChordSymbol(root: $0.root + arrangement.capo, quality: $0.quality)
        }
    }

    /// The easy open chord closest to `shape` — by circular root distance, preferring
    /// the same quality. Used to replace a chord that no capo can make open.
    private func nearestEasy(_ shape: ChordSymbol) -> ChordSymbol {
        easyShapes.min { cost($0, shape) < cost($1, shape) } ?? shape
    }

    private func cost(_ candidate: ChordSymbol, _ target: ChordSymbol) -> Int {
        let d = abs(candidate.root - target.root)
        let circular = min(d, 12 - d)
        return circular * 2 + (candidate.quality == target.quality ? 0 : 1)
    }
}
