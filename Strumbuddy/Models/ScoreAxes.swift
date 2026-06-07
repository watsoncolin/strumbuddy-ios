import Foundation

/// The four-axis scoring rubric (design-doc §4). Every observation is graded on
/// these, and both the milestone tests and the coach read them.
///
/// Values are normalized 0…1. `cleanliness` is the differentiating axis — it
/// falls out of the chromagram for free and is what competitors don't do well.
struct ScoreAxes: Codable, Hashable {
    /// Were the right notes present? (chord/note identity match)
    var accuracy: Double
    /// Did every expected string ring vs. muted / dead / buzzing?
    var cleanliness: Double
    /// Onset alignment against the metronome grid.
    var timing: Double
    /// Filled in by the aggregator: N good reps in a row. Per-attempt this is nil.
    var consistency: Double?

    init(accuracy: Double, cleanliness: Double, timing: Double, consistency: Double? = nil) {
        self.accuracy = accuracy
        self.cleanliness = cleanliness
        self.timing = timing
        self.consistency = consistency
    }

    static let zero = ScoreAxes(accuracy: 0, cleanliness: 0, timing: 0)

    /// A single blended score for simple gating. The coach prefers the individual
    /// axes (so it can say *which* axis is weak), but milestone thresholds can use this.
    var overall: Double {
        (accuracy + cleanliness + timing) / 3.0
    }
}

/// Per-string cleanliness detail (design-doc §4). This is the teacher-grade
/// feedback: "your high E is muted." Derived from per-pitch-class chromagram energy.
enum StringQuality: String, Codable {
    case clean      // expected note present with good energy
    case muted      // expected note missing / dead string
    case buzzing    // unexpected energy near the note (buzz / wrong fret)
}
