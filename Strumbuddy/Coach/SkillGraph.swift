import Foundation

/// The prerequisite DAG of skills (design-doc §5.1). Does double duty: gates what
/// the coach may suggest (prereqs must be met) and explains *why* a user is stuck.
struct SkillGraph {
    let skills: [SkillID: Skill]

    init(_ list: [Skill]) {
        self.skills = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    func skill(_ id: SkillID) -> Skill? { skills[id] }

    /// Are all prerequisites of `id` mastered? (zone-of-proximal-development gate, §5.4)
    func prerequisitesMet(_ id: SkillID, isMastered: (SkillID) -> Bool) -> Bool {
        guard let skill = skills[id] else { return false }
        return skill.prerequisites.allSatisfy(isMastered)
    }

    /// Skills that directly depend on `id` — used to compute bottleneck leverage.
    func dependents(of id: SkillID) -> [SkillID] {
        skills.values.filter { $0.prerequisites.contains(id) }.map(\.id)
    }

    /// Bottleneck leverage (§5.4): how many downstream skills a weak prerequisite
    /// blocks. A simple transitive-closure count over the DAG (graph centrality).
    func downstreamCount(of id: SkillID) -> Int {
        var seen = Set<SkillID>()
        var stack = dependents(of: id)
        while let next = stack.popLast() {
            guard !seen.contains(next) else { continue }
            seen.insert(next)
            stack.append(contentsOf: dependents(of: next))
        }
        return seen.count
    }

    // MARK: - The v0.1 beginner curriculum

    /// The starter graph: the open chords, the transitions between the common ones,
    /// and a couple of tempo holds. Transitions depend on their two chords (§5.1).
    static func beginnerGraph() -> SkillGraph {
        var skills: [Skill] = []

        // Chord nodes — no prerequisites (the F barre is gated by being later in the path).
        for chord in Chord.allCases {
            skills.append(Skill(id: .chord(chord), kind: .chord(chord), prerequisites: []))
        }

        // The classic early transitions beginners drill.
        let pairs: [(Chord, Chord)] = [
            (.em, .c), (.c, .g), (.g, .d), (.d, .a), (.a, .e),
            (.em, .g), (.c, .d), (.am, .c), (.g, .c), (.d, .g)
        ]
        for (a, b) in pairs {
            skills.append(Skill(id: .transition(from: a, to: b),
                                kind: .transition(from: a, to: b),
                                prerequisites: [.chord(a), .chord(b)]))
        }

        // Tempo holds depend on having some transitions under the belt.
        skills.append(Skill(id: .tempoHold(60), kind: .tempoHold(bpm: 60),
                            prerequisites: [.transition(from: .c, to: .g)]))
        skills.append(Skill(id: .tempoHold(80), kind: .tempoHold(bpm: 80),
                            prerequisites: [.tempoHold(60)]))

        return SkillGraph(skills)
    }
}
