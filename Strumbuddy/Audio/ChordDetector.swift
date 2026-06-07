import Foundation

/// Template-matching chord detector over the constrained beginner set (design-doc §4).
/// Matches a chromagram against the expected pitch classes of each supported chord —
/// far more accurate than universal recognition because the candidate set is tiny.
///
/// Produces the two distinct things the app needs from one analysis:
///   • identity + `confidence` (the accuracy axis): which chord, how sure.
///   • `cleanliness` + per-pitch-class `stringQuality` (the differentiating axis):
///     is every expected note ringing, is anything missing (muted) or extra (buzz)?
struct ChordDetector {
    /// Normalized energy above which an expected pitch class counts as "present."
    /// Lower = more forgiving of quieter strings (so you don't have to play loud),
    /// but too low lets harmonic leakage read a muted string as ringing.
    var presenceThreshold: Float = 0.28
    /// Higher bar for flagging an *unexpected* pitch class as a buzz/wrong note, so
    /// ordinary harmonic leakage isn't mistaken for a mistake.
    var buzzThreshold: Float = 0.5

    struct Result: Equatable {
        let chord: Chord
        /// Identity confidence 0…1 — how well the chroma fit this chord (accuracy axis).
        let confidence: Double
        /// How cleanly all expected strings ring 0…1 (cleanliness axis).
        let cleanliness: Double
        /// Per-pitch-class quality: clean/muted for expected notes, buzzing for
        /// unexpected notes ringing loudly. The basis of teacher-grade feedback.
        let stringQuality: [PitchClass: StringQuality]
    }

    /// Best-matching chord for a chromagram, or nil if nothing matches well.
    /// Use when we don't know what the user intends to play (free detection).
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

    /// Score a specific expected chord — used when we already know what the user is
    /// supposed to be playing (structured path / chord drills), the common case.
    func score(_ chord: Chord, _ chroma: [Float]) -> Result {
        guard chroma.count == 12 else {
            return Result(chord: chord, confidence: 0, cleanliness: 0, stringQuality: [:])
        }
        let expected = chord.expectedPitchClasses
        var present = 0
        var quality: [PitchClass: StringQuality] = [:]
        var allUnexpectedEnergy: Float = 0   // for identity confidence
        var buzzEnergy: Float = 0            // only strong unexpected notes, for cleanliness

        for pc in PitchClass.allCases {
            let energy = chroma[pc.rawValue]
            if expected.contains(pc) {
                if energy >= presenceThreshold {
                    present += 1
                    quality[pc] = .clean
                } else {
                    quality[pc] = .muted   // expected note missing → muted / dead string
                }
            } else {
                allUnexpectedEnergy += energy
                if energy >= buzzThreshold {
                    quality[pc] = .buzzing  // unexpected note ringing → buzz / wrong fret
                    buzzEnergy += energy
                }
            }
        }

        let count = max(expected.count, 1)
        let coverage = Double(present) / Double(count)

        // Identity: high coverage, penalized by any out-of-chord energy.
        let identityNoise = Double(min(allUnexpectedEnergy / Float(count), 1))
        let confidence = max(0, coverage - 0.5 * identityNoise)

        // Cleanliness: all expected notes ringing, penalized by loud extra notes.
        let buzzPenalty = Double(min(buzzEnergy / Float(count), 1))
        let cleanliness = max(0, coverage - 0.4 * buzzPenalty)

        return Result(chord: chord, confidence: confidence, cleanliness: cleanliness,
                      stringQuality: quality)
    }
}

/// Stabilizes a stream of per-buffer chord scores for a steady live readout using
/// PEAK-HOLD: it keeps the *best* result of the current strum and holds it through
/// the note's natural decay, clearing only after sustained silence.
///
/// Why peak-hold (vs. a running average): a plucked chord is cleanest right after
/// the attack and degrades as strings die at different rates. Averaging punishes
/// that decay, forcing you to play loud and continuously. Peak-hold rewards a
/// single good strum — yet stays honest, because a persistently muted string never
/// rings in *any* frame, so it's still flagged. Reference type: lives on the audio
/// thread across buffers.
final class ChordScoreSmoother {
    private var best: ChordDetector.Result?
    private var quietFrames = 0
    private let holdFrames: Int

    init(holdFrames: Int = 18) {   // ~1.6s at ~11 buffers/sec
        self.holdFrames = holdFrames
    }

    /// Combined quality used to pick the best frame: identity + cleanliness.
    private func quality(_ r: ChordDetector.Result) -> Double {
        (r.confidence + r.cleanliness) / 2
    }

    /// `energetic` = the buffer actually contains playing (above an RMS floor).
    /// Quiet buffers hold the best reading, then clear after `holdFrames`.
    func push(_ result: ChordDetector.Result?, energetic: Bool) -> ChordDetector.Result? {
        if energetic, let result {
            quietFrames = 0
            if best == nil || quality(result) > quality(best!) { best = result }
        } else {
            quietFrames += 1
            if quietFrames >= holdFrames { best = nil }
        }
        return best
    }

    func reset() {
        best = nil
        quietFrames = 0
    }
}
