import Foundation

/// Projects the append-only observation log into per-skill `MasteryState`
/// (design-doc §5.5 "mastery state as a projection"). Folds each observation through
/// `CreditAssignment` and updates the affected skills' proficiency, confidence, and
/// FSRS-style stability. Because it's a pure projection, it can be replayed.
struct MasteryStore {
    private let creditAssignment = CreditAssignment()

    /// Score at/above which a single attempt counts as "clean."
    var masteryThreshold: Double = 0.75
    /// Consistency-based mastery: a skill is mastered when at least
    /// `cleanRepsRequired` of the last `consistencyWindow` attempts were clean.
    /// This is the "reliable, not perfect, not once" criterion — robust to the odd
    /// fumble, and it won't promote you off a single lucky strum.
    var consistencyWindow = 4
    var cleanRepsRequired = 3
    /// How many recent scores to retain per skill (a little more than the window).
    private let recentScoresKept = 6

    /// Rebuild all mastery states from scratch by replaying the log in order.
    func project(_ observations: [Observation], graph: SkillGraph, now: Date) -> [SkillID: MasteryState] {
        var states: [SkillID: MasteryState] = [:]

        for obs in observations.sorted(by: { $0.timestamp < $1.timestamp }) {
            // Current beliefs feed credit assignment.
            let attribution = creditAssignment.attribute(obs) { skill in
                states[skill]?.retrievability(at: obs.timestamp) ?? 0
            }

            for (skill, weight) in attribution.perSkill {
                var state = states[skill] ?? .seed(skill, now: obs.timestamp)
                update(&state, with: obs, weight: weight, at: obs.timestamp)
                states[skill] = state
            }
        }
        return states
    }

    /// Apply one weighted observation to a skill's state.
    /// Proficiency moves toward the observed score (weighted EMA); stability grows on
    /// success and shrinks on failure; confidence rises with observation count.
    private func update(_ state: inout MasteryState, with obs: Observation, weight: Double, at now: Date) {
        let score = obs.scores.overall
        let alpha = 0.3 * weight   // learning rate scaled by attribution weight

        // Decay current proficiency to now before blending in new evidence.
        let current = state.retrievability(at: now)
        let blended = current + alpha * (score - current)

        state.proficiencyAtLastPractice = min(1, max(0, blended))
        state.lastPracticed = now
        state.observationCount += 1
        state.confidence = 1 - pow(0.7, Double(state.observationCount))

        // Track recent outcomes for the consistency check.
        state.recentScores.append(score)
        if state.recentScores.count > recentScoresKept {
            state.recentScores.removeFirst(state.recentScores.count - recentScoresKept)
        }  // → 1 with more reps

        // FSRS-ish stability: good reps make the skill more durable.
        if score >= 0.7 {
            state.stabilityDays = min(state.stabilityDays * (1 + score), 365)
        } else {
            state.stabilityDays = max(state.stabilityDays * 0.5, 0.5)
        }
    }

    /// Mastered = clean on at least `cleanRepsRequired` of the last `consistencyWindow`
    /// attempts (consistency), and not decayed away since (retrievability floor).
    /// One fumble within the window can't un-master you; one lucky strum can't earn it.
    func isMastered(_ id: SkillID, in states: [SkillID: MasteryState], now: Date) -> Bool {
        guard let s = states[id] else { return false }
        let window = s.recentScores.suffix(consistencyWindow)
        let cleanReps = window.filter { $0 >= masteryThreshold }.count
        let consistent = window.count >= cleanRepsRequired && cleanReps >= cleanRepsRequired
        return consistent && s.retrievability(at: now) >= 0.5
    }
}
