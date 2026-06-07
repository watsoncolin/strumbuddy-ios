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
    /// Amplitude ratio (vs. the loudest in-range bin) above which a string that
    /// should be muted counts as "ringing." Requires a Spectrum to evaluate.
    var mutedRingThreshold: Float = 0.3

    struct Result: Equatable {
        let chord: Chord
        /// Identity confidence 0…1 — how well the chroma fit this chord (accuracy axis).
        let confidence: Double
        /// How cleanly all expected strings ring 0…1 (cleanliness axis).
        let cleanliness: Double
        /// Per-pitch-class quality: clean/muted for expected notes, buzzing for
        /// unexpected notes ringing loudly. The basis of teacher-grade feedback.
        let stringQuality: [PitchClass: StringQuality]
        /// String indices (0 = low E) that the chord says to mute but are ringing —
        /// caught via their actual fundamental frequency, even when that note is a
        /// chord tone (e.g. a ringing low E in a C chord). Empty without a Spectrum.
        let ringingMutedStrings: [Int]
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
    /// Pass `spectrum` to also detect muted strings ringing (needs the raw FFT).
    func score(_ chord: Chord, _ chroma: [Float], spectrum: Chromagram.Spectrum? = nil) -> Result {
        guard chroma.count == 12 else {
            return Result(chord: chord, confidence: 0, cleanliness: 0,
                          stringQuality: [:], ringingMutedStrings: [])
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

        // Muted strings that are actually ringing (checked by their fundamental
        // frequency, so "right note on the wrong string" is caught).
        let ringingMuted = spectrum.map { ringingMutedStrings(for: chord, spectrum: $0) } ?? []

        let count = max(expected.count, 1)
        let coverage = Double(present) / Double(count)

        // Identity: high coverage, penalized by any out-of-chord energy.
        let identityNoise = Double(min(allUnexpectedEnergy / Float(count), 1))
        let confidence = max(0, coverage - 0.5 * identityNoise)

        // Cleanliness: all expected notes ringing, penalized by loud extra notes
        // and by any string that should be muted but is ringing.
        let buzzPenalty = Double(min(buzzEnergy / Float(count), 1))
        let mutedPenalty = min(Double(ringingMuted.count) * 0.3, 0.6)
        let cleanliness = max(0, coverage - 0.4 * buzzPenalty - mutedPenalty)

        return Result(chord: chord, confidence: confidence, cleanliness: cleanliness,
                      stringQuality: quality, ringingMutedStrings: ringingMuted)
    }

    /// Which strings the chord mutes are nonetheless ringing, found by looking for
    /// energy at each muted string's open fundamental (info the chroma folds away).
    private func ringingMutedStrings(for chord: Chord, spectrum: Chromagram.Spectrum) -> [Int] {
        guard let shape = ChordShape.library[chord],
              spectrum.binWidth > 0, !spectrum.magnitudes.isEmpty else { return [] }
        let maxMag = inRangeMax(spectrum)
        guard maxMag > 0 else { return [] }

        var ringing: [Int] = []
        for i in 0..<6 where shape.frets[i] == -1 {
            let peak = bandPeak(spectrum, around: ChordShape.openStringFrequencies[i])
            if sqrt(peak / maxMag) >= mutedRingThreshold { ringing.append(i) }
        }
        return ringing
    }

    /// Peak |X|² within ±1 semitone of `freq`.
    private func bandPeak(_ s: Chromagram.Spectrum, around freq: Float) -> Float {
        let lo = max(1, Int((freq / 1.06) / s.binWidth))
        let hi = min(s.magnitudes.count - 1, Int((freq * 1.06) / s.binWidth))
        guard lo <= hi else { return 0 }
        var peak: Float = 0
        for b in lo...hi { peak = max(peak, s.magnitudes[b]) }
        return peak
    }

    /// Loudest |X|² bin within the guitar range (70–2000 Hz), avoiding DC skew.
    private func inRangeMax(_ s: Chromagram.Spectrum) -> Float {
        let lo = max(1, Int(70 / s.binWidth))
        let hi = min(s.magnitudes.count - 1, Int(2000 / s.binWidth))
        guard lo <= hi else { return 0 }
        var m: Float = 0
        for b in lo...hi { m = max(m, s.magnitudes[b]) }
        return m
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
