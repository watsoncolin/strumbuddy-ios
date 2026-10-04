import Foundation

/// The end-of-song summary (wiki: Songs). Pure, so the scoring rules are tested
/// off-device: an overall score, 0–3 stars, and the one change that cost the most —
/// the coach's "your chords are fine; it's G→C" diagnosis, scoped to this run.
struct SongReport {
    let bars: [RepResult]

    struct Change: Equatable {
        let from: Chord
        let to: Chord
        let score: Double
    }

    /// Mean of each bar's overall (accuracy + cleanliness + timing) score.
    var score: Double {
        guard !bars.isEmpty else { return 0 }
        return bars.map(\.axes.overall).reduce(0, +) / Double(bars.count)
    }

    var stars: Int { Self.stars(for: score) }

    static func stars(for score: Double) -> Int {
        switch score {
        case 0.85...: return 3
        case 0.7...:  return 2
        case 0.5...:  return 1
        default:      return 0
        }
    }

    /// The weakest chord change (averaged over every time it came up), if it fell
    /// short of clean. Held chords aren't changes; nil when every change was solid.
    var trickiestChange: Change? {
        var totals: [String: (from: Chord, to: Chord, sum: Double, n: Int)] = [:]
        for bar in bars {
            guard let prev = bar.previous, prev != bar.chord else { continue }
            let key = "\(prev.rawValue)>\(bar.chord.rawValue)"
            var t = totals[key] ?? (prev, bar.chord, 0, 0)
            t.sum += bar.axes.overall
            t.n += 1
            totals[key] = t
        }
        let worst = totals.values
            .map { Change(from: $0.from, to: $0.to, score: $0.sum / Double($0.n)) }
            .min(by: Self.weaker)
        guard let worst, worst.score < Self.cleanThreshold else { return nil }
        return worst
    }

    /// Lower score first; ties broken by name so the pick is stable.
    private static func weaker(_ a: Change, _ b: Change) -> Bool {
        if a.score != b.score { return a.score < b.score }
        let nameA: String = a.from.rawValue + a.to.rawValue
        let nameB: String = b.from.rawValue + b.to.rawValue
        return nameA < nameB
    }

    /// A bar at/above this reads as "clean" in the bar strip and summary.
    static let cleanThreshold = 0.75
}
