import Foundation

/// One graded attempt — the unit of the append-only observation log (design-doc §5.5).
///
/// A single strum is evidence about several skills at once (the chord, the next
/// chord, the transition, the tempo). So an observation lists *all* implicated
/// skills and carries CONTEXT — because a chord clean in isolation but muffed at
/// speed is evidence about a different skill than the isolated chord (§5.3).
struct Observation: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    /// Every skill this attempt is evidence about. Credit assignment (§5.3)
    /// decides how the score is apportioned across them.
    let implicatedSkills: [SkillID]
    let context: Context
    let scores: ScoreAxes

    struct Context: Codable, Hashable {
        /// Was the skill attempted alone, or embedded in a song/sequence?
        var isolation: Isolation
        /// The tempo this was played at, if any. Nil for free, untimed attempts.
        var bpm: Int?
        /// Where the attempt happened, for goal-relevance weighting later.
        var source: Source

        enum Isolation: String, Codable { case isolated, inSequence }
        enum Source: String, Codable { case structuredPath, practice, freePlay, calibration }
    }

    init(id: UUID = UUID(),
         timestamp: Date,
         implicatedSkills: [SkillID],
         context: Context,
         scores: ScoreAxes) {
        self.id = id
        self.timestamp = timestamp
        self.implicatedSkills = implicatedSkills
        self.context = context
        self.scores = scores
    }
}
