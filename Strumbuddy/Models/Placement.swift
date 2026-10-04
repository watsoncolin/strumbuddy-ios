import Foundation

/// Onboarding placement (design-doc §5.5 "cold start: a short onboarding calibration
/// seeds priors"). A returning player says which chords they already know; each gets
/// just enough `.calibration` evidence to count as mastered, so the path and coach
/// start where they are instead of at Em. Self-reported, so it's self-correcting:
/// seeded chords come due for review within days, and mastery reads the last few
/// real attempts — an overclaimed chord drops out after a couple of fumbles.
/// Changes are never seeded; they have to be played.
enum Placement {
    /// Seeded attempts per chord — the consistency criterion's minimum.
    static let attemptsPerChord = 3
    /// Clean, but only just — real play quickly outweighs it.
    static let seededScore = 0.8

    static func observations(for chords: [Chord], now: Date) -> [Observation] {
        let axes = ScoreAxes(accuracy: seededScore, cleanliness: seededScore, timing: seededScore)
        return chords.enumerated().flatMap { c, chord in
            (0..<attemptsPerChord).map { i in
                Observation(timestamp: now.addingTimeInterval(Double(c * attemptsPerChord + i) * 0.001),
                            implicatedSkills: [.chord(chord)],
                            context: .init(isolation: .isolated, bpm: nil, source: .calibration),
                            scores: axes)
            }
        }
    }
}
