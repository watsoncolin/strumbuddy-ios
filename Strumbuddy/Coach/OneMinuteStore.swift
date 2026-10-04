import Foundation
import Combine

/// History and personal bests for one-minute changes, persisted in UserDefaults
/// (small, append-only, like the streak days).
@MainActor
final class OneMinuteStore: ObservableObject {
    @Published private(set) var results: [OneMinuteResult] = []

    private let defaults: UserDefaults
    private let key = "oneMinuteResults"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([OneMinuteResult].self, from: data) {
            results = decoded
        }
    }

    /// Record a finished minute; returns true if it beat the pair's previous best.
    @discardableResult
    func record(_ result: OneMinuteResult) -> Bool {
        let previous = best(for: result.pairKey)
        results.append(result)
        if let data = try? JSONEncoder().encode(results) { defaults.set(data, forKey: key) }
        return result.changes > (previous ?? -1)
    }

    func history(for pairKey: String) -> [OneMinuteResult] {
        results.filter { $0.pairKey == pairKey }.sorted { $0.date < $1.date }
    }

    func best(for pairKey: String) -> Int? {
        history(for: pairKey).map(\.changes).max()
    }

    /// Pairs practiced, most recently played first.
    var pairs: [String] {
        var seen = Set<String>()
        return results.sorted { $0.date > $1.date }.map(\.pairKey).filter { seen.insert($0).inserted }
    }
}
