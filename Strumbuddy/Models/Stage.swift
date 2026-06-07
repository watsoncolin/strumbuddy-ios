import Foundation

/// A milestone stage in the structured path (design-doc §3 mode 1). A stage is
/// complete when all its skills are mastered (the consistency criterion); stages
/// unlock in sequence — a Couch-to-5K-style ladder (see wiki: Learning Philosophy).
struct Stage: Identifiable {
    let id: Int
    let title: String
    let blurb: String
    let skills: [SkillID]

    static let beginnerStages: [Stage] = [
        Stage(id: 1, title: "First chords", blurb: "Em, C, and G — clean and ringing.",
              skills: [.chord(.em), .chord(.c), .chord(.g)]),
        Stage(id: 2, title: "First changes", blurb: "Switch between them in time.",
              skills: [.transition(from: .em, to: .c), .transition(from: .c, to: .g)]),
        Stage(id: 3, title: "Keep the beat", blurb: "Hold a change at 60 bpm.",
              skills: [.tempoHold(60)]),
        Stage(id: 4, title: "Widen the vocabulary", blurb: "Add D and A.",
              skills: [.chord(.d), .chord(.a), .transition(from: .g, to: .d)]),
    ]
}

enum StageState { case locked, active, complete }

struct StagePlan: Identifiable {
    let stage: Stage
    let state: StageState
    /// Average proficiency across the stage's skills (smooth progress bar).
    let progress: Double
    var id: Int { stage.id }
}

/// Pure gating: a stage is complete when all its skills are mastered; the first
/// not-complete stage after a run of complete ones is active; the rest are locked.
func computeStagePlans(_ stages: [Stage],
                       isMastered: (SkillID) -> Bool,
                       proficiency: (SkillID) -> Double) -> [StagePlan] {
    var previousComplete = true   // the first stage is always reachable
    var plans: [StagePlan] = []
    for stage in stages {
        let complete = !stage.skills.isEmpty && stage.skills.allSatisfy(isMastered)
        let state: StageState = complete ? .complete : (previousComplete ? .active : .locked)
        let progress = stage.skills.isEmpty ? 0
            : stage.skills.map(proficiency).reduce(0, +) / Double(stage.skills.count)
        plans.append(StagePlan(stage: stage, state: state, progress: progress))
        previousComplete = complete
    }
    return plans
}
