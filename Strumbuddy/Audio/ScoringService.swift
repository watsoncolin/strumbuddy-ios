import Foundation

/// Turns raw detections into the four-axis `ScoreAxes` and packages `Observation`s
/// for the coach (design-doc §4 + §5.5). This is the seam between the audio world
/// and the coaching world: audio produces grades, the coach consumes observations.
struct ScoringService {
    let detector = ChordDetector()

    /// Grade a chord attempt against the expected chord.
    /// `timing` is supplied by the caller (from `Metronome.timingScore`) or nil
    /// for untimed attempts.
    func gradeChord(expected: Chord, chroma: [Float], timing: Double?) -> (ScoreAxes, [PitchClass: StringQuality]) {
        let r = detector.score(expected, chroma)
        let axes = ScoreAxes(accuracy: r.confidence,
                             cleanliness: r.cleanliness,
                             timing: timing ?? r.confidence)  // fall back to accuracy when untimed
        return (axes, r.stringQuality)
    }

    /// Build an observation for a chord attempt, listing every skill it's evidence
    /// about so credit assignment (§5.3) can apportion blame. `previous` lets us
    /// add the transition node when the attempt followed another chord.
    func observation(for chord: Chord,
                     previous: Chord?,
                     axes: ScoreAxes,
                     context: Observation.Context,
                     now: Date) -> Observation {
        var skills: [SkillID] = [.chord(chord)]
        if let previous {
            skills.append(.transition(from: previous, to: chord))
            skills.append(.chord(previous))
        }
        if let bpm = context.bpm {
            skills.append(.tempoHold(bpm))
        }
        return Observation(timestamp: now,
                           implicatedSkills: skills,
                           context: context,
                           scores: axes)
    }
}
