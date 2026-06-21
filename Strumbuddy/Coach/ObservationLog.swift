import Foundation

/// Append-only observation log (design-doc §5.5). The source of truth: mastery
/// state is a *projection* over this log (event-sourcing / CDC), so inference can
/// be re-tuned and replayed without losing history.
///
/// v0.1: in-memory with JSON file persistence. Swap the backing store for SQLite
/// (see `Persistence/`) once the schema settles — the append-only API stays the same.
@MainActor
final class ObservationLog: ObservableObject {
    @Published private(set) var entries: [Observation] = []

    private let fileURL: URL

    init(filename: String = "observations.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // iOS does NOT create Application Support in the sandbox by default — unlike
        // Documents. Without this, the atomic write below fails silently (try?) and
        // nothing ever persists, so mastery resets to zero every launch.
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(filename)
        load()
    }

    /// The only mutating operation — the log never updates or deletes.
    func append(_ observation: Observation) {
        entries.append(observation)
        persist()
    }

    /// All observations implicating a given skill, newest first.
    func observations(for skill: SkillID) -> [Observation] {
        entries.filter { $0.implicatedSkills.contains(skill) }.reversed()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Observation].self, from: data)
        else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
