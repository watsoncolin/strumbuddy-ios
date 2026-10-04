import Foundation
import Combine

/// Per-song best scores and the user's goal song (wiki: Songs). The goal feeds the
/// coach's goal-relevant signal (design-doc §5.4): "you want to play this; two of its
/// chords are your weak spots." Persisted in UserDefaults like the streak.
@MainActor
final class SongProgressStore: ObservableObject {
    @Published private(set) var bests: [Int: Double] = [:]
    @Published private(set) var goalSongID: Int?

    private let coach: Coach
    private let defaults: UserDefaults
    private let bestsKey = "songBestScores"
    private let goalKey = "goalSongID"

    init(coach: Coach, defaults: UserDefaults = .standard) {
        self.coach = coach
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: bestsKey) as? [String: Double] ?? [:]
        bests = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
        goalSongID = defaults.object(forKey: goalKey) as? Int
        applyGoal()
    }

    var goalSong: Song? { Song.library.first { $0.id == goalSongID } }

    /// Record a finished run; returns true if it's a new best.
    @discardableResult
    func record(score: Double, for song: Song) -> Bool {
        guard score > (bests[song.id] ?? -1) else { return false }
        bests[song.id] = score
        defaults.set(Dictionary(uniqueKeysWithValues: bests.map { (String($0), $1) }), forKey: bestsKey)
        return true
    }

    func setGoal(_ song: Song?) {
        goalSongID = song?.id
        if let id = song?.id { defaults.set(id, forKey: goalKey) } else { defaults.removeObject(forKey: goalKey) }
        applyGoal()
    }

    private func applyGoal() {
        coach.setGoalSkills(goalSong.map(Self.skills(in:)) ?? [])
    }

    /// Every chord and chord change a song asks for — what "learn this song" means
    /// to the skill graph.
    static func skills(in song: Song) -> Set<SkillID> {
        let chords = song.flatChords
        var out = Set(chords.map { SkillID.chord($0) })
        for (a, b) in zip(chords, chords.dropFirst()) where a != b {
            out.insert(.transition(from: a, to: b))
        }
        return out
    }
}
