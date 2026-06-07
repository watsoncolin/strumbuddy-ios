import Foundation

/// Per-skill mastery (design-doc §5.2). Not a boolean "done" — guitar is physical,
/// so skill fades. Modeled like an FSRS flashcard: a skill nailed three weeks ago
/// becomes due for review. "Completed" is never permanent.
struct MasteryState: Codable, Hashable {
    let skill: SkillID

    /// "Can you play it clean right now," 0…1 — FSRS *retrievability*, decayed to now.
    /// Stored implicitly via `stability` + `lastPracticed`; see `retrievability(at:)`.
    var proficiencyAtLastPractice: Double

    /// How slowly it decays — FSRS *stability*, in days. Higher = more durable.
    var stabilityDays: Double

    /// Confidence in the estimate: a function of how many recent observations exist.
    /// Low confidence → the coach leans on calibration priors and avoids strong claims.
    var confidence: Double

    var lastPracticed: Date
    var observationCount: Int

    /// The most recent per-attempt overall scores (newest last), capped to a short
    /// window. Drives the consistency-based mastery check — "you've got it when you
    /// can play it cleanly *reliably*, not perfectly and not once."
    var recentScores: [Double]

    static func seed(_ skill: SkillID, prior: Double = 0.0, now: Date) -> MasteryState {
        MasteryState(skill: skill,
                     proficiencyAtLastPractice: prior,
                     stabilityDays: 1.0,
                     confidence: 0.0,
                     lastPracticed: now,
                     observationCount: 0,
                     recentScores: [])
    }

    /// Current retrievability, decayed from `lastPracticed` to `now`.
    /// FSRS forgetting curve: R = (1 + t / (9·S))^-1, t and S in days.
    func retrievability(at now: Date) -> Double {
        let elapsedDays = max(0, now.timeIntervalSince(lastPracticed)) / 86_400
        let r = pow(1 + elapsedDays / (9 * max(stabilityDays, 0.0001)), -1)
        return proficiencyAtLastPractice * r
    }

    /// Whether the skill is "due" — retrievability has decayed below a review threshold.
    func isDue(at now: Date, threshold: Double = 0.7) -> Bool {
        observationCount > 0 && retrievability(at: now) < threshold
    }
}
