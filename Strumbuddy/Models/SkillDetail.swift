import Foundation

/// A per-skill breakdown for the detail screen — the four scoring dimensions plus
/// mastery context, aggregated from recent observations. Pure (no engine/coach
/// types beyond the data) so it's unit-testable.
struct SkillDetail {
    let attempts: Int
    let proficiency: Double      // overall, decayed to now
    let mastered: Bool
    let lastPracticed: Date?

    // The four axes, averaged over recent attempts.
    let accuracy: Double
    let cleanliness: Double
    let timing: Double
    /// Whether any *timed* (in-sequence/drill) attempts exist — timing is only
    /// meaningful from the rhythm drill, not untimed Chord Check.
    let hasTiming: Bool
    /// Consistency = fraction of recent attempts that were clean. The 4th axis.
    let consistency: Double

    /// `observations` is assumed newest-first.
    static func make(observations: [Observation], recentLimit: Int = 10,
                     state: MasteryState?, mastered: Bool, masteryThreshold: Double,
                     now: Date) -> SkillDetail {
        let recent = Array(observations.prefix(recentLimit))
        func avg(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }

        let timed = recent.filter { $0.context.isolation == .inSequence }
        let cleanCount = recent.filter { $0.scores.overall >= masteryThreshold }.count

        return SkillDetail(
            attempts: observations.count,
            proficiency: state?.retrievability(at: now) ?? 0,
            mastered: mastered,
            lastPracticed: state?.lastPracticed,
            accuracy: avg(recent.map { $0.scores.accuracy }),
            cleanliness: avg(recent.map { $0.scores.cleanliness }),
            timing: avg(timed.map { $0.scores.timing }),
            hasTiming: !timed.isEmpty,
            consistency: recent.isEmpty ? 0 : Double(cleanCount) / Double(recent.count))
    }
}
