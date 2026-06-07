import Foundation

/// "What should I work on?" — a weighted pick over the graph (design-doc §5.4),
/// blending four signals. Every recommendation is graph-derived, so it's explainable.
///
/// OPEN QUESTION (§8): the weighting math so suggestions don't feel repetitive.
/// These weights are a starting point; tune against real sessions.
struct SelectionPolicy {
    struct Weights {
        var weakestButReady = 1.0
        var decayDue = 0.8
        var goalRelevant = 1.2
        var bottleneckLeverage = 0.6
    }

    struct Recommendation: Identifiable {
        let id: SkillID
        let skill: Skill
        let score: Double
        /// Why this was chosen — shown to the user (§5.4 explainability).
        let reason: String
    }

    var weights = Weights()
    /// Skills tied to a user goal (e.g. chords in a saved song). v2 BYO-song fills this.
    var goalSkills: Set<SkillID> = []

    func recommend(graph: SkillGraph,
                   states: [SkillID: MasteryState],
                   store: MasteryStore,
                   now: Date,
                   limit: Int = 3) -> [Recommendation] {
        var recs: [Recommendation] = []

        for (id, skill) in graph.skills {
            let mastered = store.isMastered(id, in: states, now: now)
            let ready = graph.prerequisitesMet(id) { store.isMastered($0, in: states, now: now) }
            guard ready else { continue }   // never suggest the unattemptable (ZPD)

            let proficiency = states[id]?.retrievability(at: now) ?? 0
            var score = 0.0
            var reasons: [String] = []

            // 1. Weakest-but-ready — unmastered, prereqs satisfied.
            if !mastered {
                score += weights.weakestButReady * (1 - proficiency)
                reasons.append("it's a weak spot you're ready for")
            }
            // 2. Decay-due — spaced-repetition resurfacing.
            if let s = states[id], s.isDue(at: now) {
                score += weights.decayDue * (1 - proficiency)
                reasons.append("it's due for review")
            }
            // 3. Goal-relevant.
            if goalSkills.contains(id) {
                score += weights.goalRelevant
                reasons.append("it's in a song you want to play")
            }
            // 4. Bottleneck leverage — weak prereq blocking many downstream skills.
            if !mastered {
                let downstream = graph.downstreamCount(of: id)
                if downstream > 0 {
                    score += weights.bottleneckLeverage * Double(downstream) / 10.0
                    reasons.append("it unlocks \(downstream) later skill\(downstream == 1 ? "" : "s")")
                }
            }

            guard score > 0 else { continue }
            recs.append(Recommendation(id: id, skill: skill, score: score,
                                       reason: reasons.joined(separator: ", ")))
        }

        return Array(recs.sorted { $0.score > $1.score }.prefix(limit))
    }
}
