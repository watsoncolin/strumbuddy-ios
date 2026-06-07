import Foundation

/// Template-matching chord detector over the constrained beginner set (design-doc §4).
/// Matches a chromagram against the expected pitch classes of each supported chord —
/// far more accurate than universal recognition because the candidate set is tiny.
struct ChordDetector {
    /// Energy threshold above which a pitch class counts as "present."
    var presenceThreshold: Float = 0.35

    struct Result {
        let chord: Chord
        /// Match confidence 0…1 — how well the chroma fit this chord's template.
        let confidence: Double
        /// Per-expected-note quality, the basis of the cleanliness axis (§4).
        let stringQuality: [PitchClass: StringQuality]
    }

    /// Best-matching chord for a chromagram, or nil if nothing matches well.
    func detect(_ chroma: [Float]) -> Result? {
        guard chroma.count == 12 else { return nil }
        var best: Result?
        for chord in Chord.allCases {
            let r = score(chord, chroma)
            if r.confidence > (best?.confidence ?? 0) { best = r }
        }
        guard let best, best.confidence > 0.5 else { return nil }
        return best
    }

    /// Score a specific expected chord — used when we already know what the user
    /// is supposed to be playing (structured path / drills), which is the common case.
    func score(_ chord: Chord, _ chroma: [Float]) -> Result {
        let expected = chord.expectedPitchClasses
        var present = 0
        var quality: [PitchClass: StringQuality] = [:]

        for pc in expected {
            let energy = chroma[pc.rawValue]
            if energy >= presenceThreshold {
                present += 1
                quality[pc] = .clean
            } else {
                quality[pc] = .muted   // expected note missing → muted/dead string
            }
        }

        // Unexpected energy → buzz / wrong fret. Penalizes accuracy.
        var unexpectedEnergy: Float = 0
        for pc in PitchClass.allCases where !expected.contains(pc) {
            unexpectedEnergy += chroma[pc.rawValue]
        }

        let coverage = Double(present) / Double(expected.count)
        let noise = Double(min(unexpectedEnergy / Float(max(expected.count, 1)), 1))
        let confidence = max(0, coverage - 0.5 * noise)
        return Result(chord: chord, confidence: confidence, stringQuality: quality)
    }
}
