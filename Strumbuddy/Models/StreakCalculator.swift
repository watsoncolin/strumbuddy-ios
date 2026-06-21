import Foundation

/// Streak math with forgiveness (see wiki: Daily Practice Loop). Pure — operates on
/// day-ordinals (integer day numbers), so it's testable without calendar plumbing;
/// the app converts dates → ordinals via `Calendar`.
enum StreakCalculator {
    /// Current streak counting back from `today`:
    ///  - today not done yet does NOT break the streak (it's still alive),
    ///  - up to `freezes` missed days within the run are bridged (forgiveness),
    ///  - two-plus consecutive misses (beyond freezes) end it.
    static func current(days: Set<Int>, today: Int, freezes: Int = 1) -> Int {
        guard let earliest = days.min() else { return 0 }
        var streak = 0
        var freezesLeft = freezes
        var day = today
        while day >= earliest {
            if days.contains(day) {
                streak += 1
            } else if day == today {
                // Today isn't done yet — costs nothing, doesn't break the streak.
            } else if freezesLeft > 0 {
                freezesLeft -= 1   // a freeze bridges this missed day
            } else {
                break
            }
            day -= 1
        }
        return streak
    }

    /// Whether returning *today* was saved by a freeze: you played today, missed
    /// yesterday, yet the streak spans the gap. Drives the "welcome back — streak
    /// saved" message (forgiveness, not punishment). True only on the return day.
    static func freezeUsed(days: Set<Int>, today: Int, freezes: Int = 1) -> Bool {
        days.contains(today)
            && !days.contains(today - 1)
            && current(days: days, today: today, freezes: freezes) > 1
    }
}
