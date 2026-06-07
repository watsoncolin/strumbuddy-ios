import Foundation

/// Credit assignment (design-doc §5.3) — "the magic." A single strummed G→C is
/// evidence about five nodes at once (G, C, the transition, tempo, strum). When it
/// fails, which do we blame? We disambiguate using the graph + observation context.
///
/// OPEN QUESTION (§8): the exact blame-propagation mechanism. This is a defensible
/// v1 heuristic, deliberately simple and explainable, to be replaced by a principled
/// model (Bayesian knowledge tracing) later. The interface is what matters now.
struct CreditAssignment {
    /// How much weight a single observation contributes to each implicated skill.
    /// Sums to ~1 across the returned skills.
    struct Attribution {
        let perSkill: [SkillID: Double]
        /// Human-readable reason, so the coach can show its work (§5.4 explainability).
        let rationale: String
    }

    /// Decide how to apportion an observation's evidence across its implicated skills,
    /// given what we already believe about each (their current retrievability).
    ///
    /// Heuristic: if the standalone chords are independently solid but a transition
    /// or tempo skill is also implicated and the attempt scored poorly, concentrate
    /// blame on the transition/tempo. Otherwise spread evidence evenly.
    func attribute(_ obs: Observation,
                   beliefs: (SkillID) -> Double) -> Attribution {
        let skills = obs.implicatedSkills
        guard !skills.isEmpty else { return Attribution(perSkill: [:], rationale: "no skills") }

        let chordSkills = skills.filter { $0.rawValue.hasPrefix("chord.") }
        let structural = skills.filter {
            $0.rawValue.hasPrefix("transition.") || $0.rawValue.hasPrefix("tempo.")
        }

        // Are the component chords already solid on their own?
        let chordsSolid = chordSkills.allSatisfy { beliefs($0) >= 0.7 }
        let poorAttempt = obs.scores.overall < 0.6

        if poorAttempt, chordsSolid, !structural.isEmpty {
            // The chords aren't the problem — blame the structural skill.
            let w = 1.0 / Double(structural.count)
            let perSkill = Dictionary(uniqueKeysWithValues: structural.map { ($0, w) })
            return Attribution(perSkill: perSkill,
                               rationale: "Component chords are solid; concentrating evidence on the change/tempo.")
        }

        // Default: spread evidence evenly across everything implicated.
        let w = 1.0 / Double(skills.count)
        let perSkill = Dictionary(uniqueKeysWithValues: skills.map { ($0, w) })
        return Attribution(perSkill: perSkill, rationale: "Evidence spread across all implicated skills.")
    }
}
