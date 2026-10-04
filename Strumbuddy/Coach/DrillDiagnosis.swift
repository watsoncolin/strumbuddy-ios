import Foundation

/// The coach's one-line verdict on a graded run (drill or song) — the explainable
/// diagnosis the design doc promises (§1, §5.3): not "68%", but *"your C is fine;
/// it's the change into it."* Pure: reads the run's bars plus what the coach already
/// believes about each chord on its own, so it's tested off-device.
struct DrillDiagnosis: Equatable {
    enum Kind: Equatable {
        case clean
        case late(Chord)
        case rushing(Chord)
        case unsteady
        /// The chord is solid alone; the change into it breaks down.
        case change(from: Chord?, to: Chord)
        /// The chord itself isn't there yet.
        case chord(Chord)
    }

    let kind: Kind

    /// Mean axis at/above which a run reads as clean.
    static let cleanBar = 0.75
    /// An offset beyond this (seconds) counts as clearly late/early for that bar.
    static let offBeat = 0.08
    /// Coach belief at/above which a chord is "solid on its own."
    static let solidChord = 0.7

    /// `chordBelief` is the coach's current proficiency for a chord (0…1).
    static func make(_ bars: [RepResult], chordBelief: (Chord) -> Double) -> DrillDiagnosis? {
        guard !bars.isEmpty else { return nil }
        func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }
        let accuracy = mean(bars.map(\.axes.accuracy))
        let cleanliness = mean(bars.map(\.axes.cleanliness))
        let timing = mean(bars.map(\.axes.timing))

        if min(accuracy, cleanliness, timing) >= cleanBar { return .init(kind: .clean) }

        // Timing is the weak axis: say which way, and where it happens most.
        if timing < min(accuracy, cleanliness) {
            let late = bars.filter { ($0.timingOffset ?? 0) > offBeat }
            let early = bars.filter { ($0.timingOffset ?? 0) < -offBeat }
            if late.count > early.count, late.count * 3 >= bars.count, let c = mostCommon(late.map(\.chord)) {
                return .init(kind: .late(c))
            }
            if early.count > late.count, early.count * 3 >= bars.count, let c = mostCommon(early.map(\.chord)) {
                return .init(kind: .rushing(c))
            }
            return .init(kind: .unsteady)
        }

        // A shape problem: find the chord that lands worst, then use the coach's
        // standalone belief to blame the change (chord is solid) or the chord.
        let byChord = Dictionary(grouping: bars, by: \.chord)
        let worst = byChord.min { a, b in
            let l = mean(a.value.map(\.axes.overall)), r = mean(b.value.map(\.axes.overall))
            return l != r ? l < r : a.key.rawValue < b.key.rawValue
        }!
        let chord = worst.key
        if chordBelief(chord) >= solidChord {
            let from = mostCommon(worst.value.compactMap(\.previous))
            return .init(kind: .change(from: from, to: chord))
        }
        return .init(kind: .chord(chord))
    }

    private static func mostCommon(_ chords: [Chord]) -> Chord? {
        let counts = Dictionary(grouping: chords, by: { $0 }).mapValues(\.count)
        return counts.max { a, b in a.value != b.value ? a.value < b.value : a.key.rawValue > b.key.rawValue }?.key
    }

    /// What the coach says.
    var message: String {
        switch kind {
        case .clean:
            return "Clean and in time — this one's ready to speed up."
        case .late(let c):
            return "Your shapes are ringing — it's the timing. You're landing \(c.displayName) late; start moving on beat 4 so it's there for the 1."
        case .rushing(let c):
            return "You're rushing into \(c.displayName). Hold the last chord until the beat, then change — let the click lead."
        case .unsteady:
            return "Your shapes are fine; the timing wobbles. Keep your strumming hand moving through the change, even if the chord isn't fully there yet."
        case .change(let from, let to):
            let into = from.map { "from \($0.displayName) " } ?? ""
            return "Your \(to.displayName) is solid on its own — it's the change \(into)into it that's falling apart. Lift all your fingers together and land the shape as one."
        case .chord(let c):
            return "\(c.displayName) itself still needs work. A few minutes in Chord Check on \(c.displayName) will make this much easier."
        }
    }
}
