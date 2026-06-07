import Foundation

/// Tracks completed daily sessions and the practice streak (wiki: Daily Practice
/// Loop). Persists the set of completed day-ordinals in UserDefaults; the streak
/// math is the pure, tested `StreakCalculator`.
@MainActor
final class PracticeTracker: ObservableObject {
    @Published private(set) var streak = 0
    @Published private(set) var completedToday = false

    private let defaultsKey = "completedSessionDays"
    private let calendar = Calendar.current
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recompute()
    }

    /// Mark today's session done (idempotent within a day) and refresh the streak.
    func recordSessionCompleted(now: Date = Date()) {
        var days = loadDays()
        days.insert(ordinal(now))
        defaults.set(Array(days), forKey: defaultsKey)
        recompute(now: now)
    }

    private func recompute(now: Date = Date()) {
        let days = loadDays()
        let today = ordinal(now)
        streak = StreakCalculator.current(days: days, today: today)
        completedToday = days.contains(today)
    }

    private func loadDays() -> Set<Int> {
        Set((defaults.array(forKey: defaultsKey) as? [Int]) ?? [])
    }

    /// Monotonic day number (era-based), so consecutive calendar days differ by 1.
    private func ordinal(_ date: Date) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }
}
