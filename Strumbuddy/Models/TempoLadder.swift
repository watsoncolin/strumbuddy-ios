import Foundation

/// The tempo ladder: once a change is clean at a tempo, the next drill starts a rung
/// faster (wiki: Rhythm Mode). Also maps any played tempo onto the graph's tempo-hold
/// levels, so a song at 65 bpm is evidence for "hold 60" rather than an orphan
/// `tempo.65` skill. Pure, so it's tested off-device.
enum TempoLadder {
    /// The tempo-hold skills in the graph (`SkillGraph.beginnerGraph`).
    static let holdLevels = [60, 80, 100]
    static let start = 60
    /// ~10% per rung at beginner tempos — small enough to feel achievable.
    static let step = 6
    static let ceiling = 160
    /// A tempo is cleared when this many most-recent attempts at it average clean.
    static let window = 4
    static let clearScore = 0.75

    /// The highest tempo-hold level at or below `bpm`, or nil below the first.
    static func holdLevel(for bpm: Int) -> Int? {
        holdLevels.last { $0 <= bpm }
    }

    /// Whether the newest `window` attempts at exactly `bpm` average clean.
    /// `observations` are newest first (as `ObservationLog.observations(for:)`).
    static func cleared(_ bpm: Int, in observations: [Observation]) -> Bool {
        let recent = observations.filter { $0.context.bpm == bpm }.prefix(window)
        guard recent.count == window else { return false }
        return recent.map(\.scores.overall).reduce(0, +) / Double(window) >= clearScore
    }

    /// The highest tempo cleared so far, if any.
    static func bestCleared(in observations: [Observation]) -> Int? {
        Set(observations.compactMap(\.context.bpm)).sorted(by: >).first { cleared($0, in: observations) }
    }

    /// Where the next drill of this change should start: one rung above the best
    /// cleared tempo, or the starting tempo if nothing's cleared yet.
    static func suggestedBPM(_ observations: [Observation]) -> Int {
        bestCleared(in: observations).map { min($0 + step, ceiling) } ?? start
    }
}
