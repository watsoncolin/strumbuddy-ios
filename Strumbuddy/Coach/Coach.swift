import Foundation
import Combine

/// The coach facade (design-doc §5). Ties together the skill graph, the observation
/// log, the mastery projection, and the selection policy — and is the single object
/// the UI talks to. Record attempts in; read recommendations and mastery out.
@MainActor
final class Coach: ObservableObject {
    let graph: SkillGraph
    let log: ObservationLog

    @Published private(set) var mastery: [SkillID: MasteryState] = [:]
    @Published private(set) var recommendations: [SelectionPolicy.Recommendation] = []

    private let store = MasteryStore()
    private var policy = SelectionPolicy()
    private let sessionGenerator = SessionGenerator()

    init(graph: SkillGraph, log: ObservationLog) {
        self.graph = graph
        self.log = log
        refresh()
    }

    /// Record a graded attempt and re-project. The audio side calls this.
    func record(_ observation: Observation) {
        log.append(observation)
        refresh()
    }

    /// Skills tied to a user goal (v2 BYO-song feeds this).
    func setGoalSkills(_ skills: Set<SkillID>) {
        policy.goalSkills = skills
        refresh()
    }

    /// Re-derive mastery and recommendations from the log (the §5.5 projection).
    func refresh(now: Date = Date()) {
        mastery = store.project(log.entries, graph: graph, now: now)
        recommendations = policy.recommend(graph: graph, states: mastery, store: store, now: now)
    }

    /// Convenience read for views: mastery 0…1 for a skill, decayed to now.
    func proficiency(_ id: SkillID, now: Date = Date()) -> Double {
        mastery[id]?.retrievability(at: now) ?? 0
    }

    /// The coach-built daily session (Tune → Review → Focus → Stretch → win).
    func todaySession(now: Date = Date()) -> [SessionBlock] {
        sessionGenerator.plan(graph: graph, states: mastery, store: store, now: now)
    }

    /// Whether a skill is mastered (consistency criterion), for the structured path.
    func isMastered(_ id: SkillID, now: Date = Date()) -> Bool {
        store.isMastered(id, in: mastery, now: now)
    }

    /// The structured-path ladder with locked/active/complete states.
    func stagePlans(now: Date = Date()) -> [StagePlan] {
        computeStagePlans(Stage.beginnerStages,
                          isMastered: { store.isMastered($0, in: mastery, now: now) },
                          proficiency: { proficiency($0, now: now) })
    }

    /// Per-skill detail (four axes + mastery context) for the detail screen.
    func detail(for id: SkillID, now: Date = Date()) -> SkillDetail {
        SkillDetail.make(
            observations: log.observations(for: id),
            state: mastery[id],
            mastered: store.isMastered(id, in: mastery, now: now),
            masteryThreshold: store.masteryThreshold,
            now: now)
    }
}
