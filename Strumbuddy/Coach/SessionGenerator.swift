import Foundation

/// What a session block has you do — each maps to a tool we already built.
enum PracticeActivity: Hashable {
    case tune
    case chord(Chord)
    case transition(from: Chord, to: Chord)
}

/// One block of the daily session.
struct SessionBlock: Identifiable, Equatable {
    let id: Int
    let kind: Kind
    let activity: PracticeActivity
    let title: String
    let detail: String

    enum Kind: String { case tune, review, focus, stretch, win }
}

/// Builds the daily "Today" session (see wiki: Daily Practice Loop). Pure — it just
/// orchestrates the coach's existing selection logic into an ordered, coach-driven
/// sequence that always ends on a win:
///   Tune → Review (decay-due) → Focus (weakest-but-ready) → Stretch → End-on-a-win.
struct SessionGenerator {
    var policy = SelectionPolicy()

    func plan(graph: SkillGraph, states: [SkillID: MasteryState],
              store: MasteryStore, now: Date) -> [SessionBlock] {
        var out: [SessionBlock] = []
        var used = Set<PracticeActivity>()

        func add(_ kind: SessionBlock.Kind, _ activity: PracticeActivity,
                 _ title: String, _ detail: String) {
            guard !used.contains(activity) else { return }
            used.insert(activity)
            out.append(SessionBlock(id: out.count, kind: kind, activity: activity,
                                    title: title, detail: detail))
        }

        // 1. Always tune first — quick, necessary, an instant win.
        add(.tune, .tune, "Tune up", "Get in tune first")

        // 2. Review: the most-decayed skill that's due.
        if let due = states.values
            .filter({ $0.isDue(at: now) })
            .sorted(by: { $0.retrievability(at: now) < $1.retrievability(at: now) })
            .first(where: { activity(for: $0.skill, graph: graph) != nil }),
           let act = activity(for: due.skill, graph: graph) {
            add(.review, act, "Review", graph.skill(due.skill)?.displayName ?? "Warm up")
        }

        // 3 & 4. Focus + stretch from the coach's ranked recommendations.
        let recs = policy.recommend(graph: graph, states: states, store: store, now: now, limit: 6)
            .filter { activity(for: $0.id, graph: graph) != nil }
        if let focus = recs.first, let act = activity(for: focus.id, graph: graph) {
            add(.focus, act, "Focus", "\(focus.skill.displayName) — \(focus.reason)")
        }
        if let stretch = recs.dropFirst().first(where: {
            guard let a = activity(for: $0.id, graph: graph) else { return false }
            return !used.contains(a)
        }), let act = activity(for: stretch.id, graph: graph) {
            add(.stretch, act, "Stretch", stretch.skill.displayName)
        }

        // 5. End on a win: a mastered skill (highest proficiency), else an easy chord.
        let winState = states.values
            .filter { store.isMastered($0.skill, in: states, now: now) }
            .sorted(by: { $0.retrievability(at: now) > $1.retrievability(at: now) })
            .first(where: { activity(for: $0.skill, graph: graph) != nil })
        let winActivity = winState.flatMap { activity(for: $0.skill, graph: graph) } ?? .chord(.em)
        // Always append (even if repeated) so the session closes on a success.
        out.append(SessionBlock(id: out.count, kind: .win, activity: winActivity,
                                title: "Finish strong", detail: "End on something you've got"))
        return out
    }

    /// Map a skill to the activity that practices it (chords → Chord Check, transitions
    /// → the drill). Returns nil for skills with no direct activity (e.g. tempo holds).
    func activity(for id: SkillID, graph: SkillGraph) -> PracticeActivity? {
        switch graph.skill(id)?.kind {
        case .chord(let c):             return .chord(c)
        case .transition(let a, let b): return .transition(from: a, to: b)
        default:                        return nil
        }
    }
}
