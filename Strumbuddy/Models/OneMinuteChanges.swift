import Foundation

/// One-minute changes — the classic beginner benchmark: how many clean switches
/// between two chords you can make in 60 seconds. A number that reliably goes up,
/// which is exactly what a beginner in week three needs to see (wiki: Retention).
struct OneMinuteResult: Codable, Hashable, Identifiable {
    var id: Date { date }
    let date: Date
    let from: Chord
    let to: Chord
    let changes: Int

    /// Order-independent key — C↔G and G↔C are the same exercise.
    var pairKey: String { Self.key(from, to) }

    static func key(_ a: Chord, _ b: Chord) -> String {
        [a.rawValue, b.rawValue].sorted().joined(separator: "↔")
    }
}

/// Counts changes from the engine's finalized strums. The target alternates: land
/// the first chord clean to start, then each clean landing on the *other* chord is
/// one change. A strum that misses doesn't count and doesn't advance the target.
struct OneMinuteCounter {
    let first: Chord
    let second: Chord
    private(set) var target: Chord
    private(set) var changes = 0
    private(set) var started = false

    /// Accuracy a landing needs — the same bar the daily session's chord blocks use.
    static let threshold = 0.6

    init(first: Chord, second: Chord) {
        self.first = first
        self.second = second
        self.target = first
    }

    /// Feed one finalized strum; returns true if it landed the target.
    @discardableResult
    mutating func strum(_ chord: Chord, confidence: Double) -> Bool {
        guard chord == target, confidence >= Self.threshold else { return false }
        if started { changes += 1 } else { started = true }
        target = target == first ? second : first
        return true
    }
}

/// Aggregations for the progress screen. Pure, so they're tested off-device.
enum ProgressStats {
    struct Day: Identifiable, Equatable {
        var id: Date { date }
        let date: Date
        let attempts: Int
    }

    /// Graded attempts per calendar day for the last `days` days, oldest first,
    /// zero-filled so quiet days show as gaps rather than disappearing.
    static func dailyAttempts(_ observations: [Observation], days: Int, now: Date,
                              calendar: Calendar = .current) -> [Day] {
        let today = calendar.startOfDay(for: now)
        var counts: [Date: Int] = [:]
        for o in observations { counts[calendar.startOfDay(for: o.timestamp), default: 0] += 1 }
        return (0..<days).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: today).map { Day(date: $0, attempts: counts[$0] ?? 0) }
        }
    }
}
