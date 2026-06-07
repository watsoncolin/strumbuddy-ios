import Foundation

/// Projects the append-only observation log into per-skill `MasteryState`
/// (design-doc §5.5 "mastery state as a projection"). Folds each observation through
/// `CreditAssignment` and updates the affected skills' proficiency, confidence, and
/// FSRS-style stability. Because it's a pure projection, it can be replayed.
struct MasteryStore {
    private let creditAssignment = CreditAssignment()

    /// Mastery threshold used for prerequisite gating.
    var masteryThreshold: Double = 0.75

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
        state.confidence = 1 - pow(0.7, Double(state.observationCount))  // → 1 with more reps

        // FSRS-ish stability: good reps make the skill more durable.
        if score >= 0.7 {
            state.stabilityDays = min(state.stabilityDays * (1 + score), 365)
        } else {
            state.stabilityDays = max(state.stabilityDays * 0.5, 0.5)
        }
    }

    func isMastered(_ id: SkillID, in states: [SkillID: MasteryState], now: Date) -> Bool {
        guard let s = states[id] else { return false }
        return s.retrievability(at: now) >= masteryThreshold && s.confidence >= 0.5
    }
}
