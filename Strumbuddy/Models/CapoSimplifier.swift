import Foundation

/// A general chord (root + quality) for the BYO-song simplifier — beyond the fixed
/// beginner `Chord` set, since a detected song can contain any chord. 7ths etc. are
/// reduced to major/minor upstream (never change major↔minor — that destroys the song).
struct ChordSymbol: Hashable {
    let root: Int      // pitch class, 0 = C … 11 = B
    let quality: Quality
    enum Quality: Hashable { case major, minor }

    init(root: Int, quality: Quality) {
        self.root = ((root % 12) + 12) % 12
        self.quality = quality
    }

    /// Map a supported beginner chord to its symbol (for personalization / diagrams).
    init(_ chord: Chord) {
        switch chord {
        case .c:  self.init(root: 0, quality: .major)
        case .a:  self.init(root: 9, quality: .major)
        case .g:  self.init(root: 7, quality: .major)
        case .e:  self.init(root: 4, quality: .major)
        case .d:  self.init(root: 2, quality: .major)
        case .f:  self.init(root: 5, quality: .major)
        case .em: self.init(root: 4, quality: .minor)
        case .am: self.init(root: 9, quality: .minor)
        }
    }

    private static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    var displayName: String { Self.names[root] + (quality == .minor ? "m" : "") }

    /// The three pitch classes of the triad (root, 3rd, 5th).
    var pitchClasses: [Int] {
        let third = quality == .major ? 4 : 3
        return [root, (root + third) % 12, (root + 7) % 12]
    }

    /// The shape you finger to sound this chord with a capo at `capo` — i.e. this chord
    /// transposed *down* by `capo` semitones.
    func shape(capo: Int) -> ChordSymbol {
        ChordSymbol(root: root - capo, quality: quality)
    }

    /// Standard beginner open-position shapes (no barre).
    static let openShapes: Set<ChordSymbol> = [
        ChordSymbol(root: 0, quality: .major),  // C
        ChordSymbol(root: 9, quality: .major),  // A
        ChordSymbol(root: 7, quality: .major),  // G
        ChordSymbol(root: 4, quality: .major),  // E
        ChordSymbol(root: 2, quality: .major),  // D
        ChordSymbol(root: 4, quality: .minor),  // Em
        ChordSymbol(root: 9, quality: .minor),  // Am
        ChordSymbol(root: 2, quality: .minor),  // Dm
    ]
}

/// Picks a capo position that lets a song be played with easy open shapes — the
/// satisfying core of [[BYO-Song (v2)]]. A capo raises pitch, so fingering an open
/// shape at fret N sounds N semitones higher; equivalently the shape you finger is
/// the song chord transposed down N. We score each capo by how much of the song
/// (weighted by how often each chord occurs) lands on shapes the player can do, and
/// pick the lowest capo with the best coverage. Pure — no audio pipeline needed.
struct CapoSimplifier {
    var maxFret = 7
    /// The shapes the player can use — default is all beginner open shapes; pass the
    /// user's mastered chords (as symbols) to personalize.
    var easyShapes: Set<ChordSymbol> = ChordSymbol.openShapes

    struct Suggestion: Equatable {
        let capo: Int
        let coverage: Double            // weighted fraction playable as easy shapes
        let shapes: [ChordSymbol]       // shape to finger per input chord, in order
    }

    /// `chords` are the song's sounding chords (dedupe first; pass `weights` = how
    /// often each occurs to favour the common ones).
    func suggest(for chords: [ChordSymbol], weights: [Int]? = nil) -> Suggestion {
        guard !chords.isEmpty else { return Suggestion(capo: 0, coverage: 0, shapes: []) }
        let w = weights ?? Array(repeating: 1, count: chords.count)
        let total = Double(w.reduce(0, +))

        var best = Suggestion(capo: 0, coverage: -1, shapes: [])
        for capo in 0...maxFret {
            let shapes = chords.map { $0.shape(capo: capo) }
            var covered = 0
            for (i, shape) in shapes.enumerated() where easyShapes.contains(shape) {
                covered += w[i]
            }
            let coverage = total > 0 ? Double(covered) / total : 0
            if coverage > best.coverage {   // strict → keeps the lowest capo on ties
                best = Suggestion(capo: capo, coverage: coverage, shapes: shapes)
            }
        }
        return best
    }
}
