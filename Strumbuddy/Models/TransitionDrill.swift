import Foundation

/// Pure scheduling for the transition drill: one count-in bar, then `totalReps` bars
/// each alternating between two chords. Maps the metronome's downbeat number to
/// "record this rep / start that rep / finished", so the real-time session carries
/// no off-by-one logic of its own (and this part is unit-testable).
struct DrillSchedule {
    let totalReps: Int
    var countInBars = 1

    struct Step: Equatable {
        let recordRep: Int?   // the rep that just ended (record it), if any
        let startRep: Int?    // the rep now starting (set the target), if any
        let finished: Bool
    }

    /// `downbeat` is 1-based — the metronome's first downbeat is 1.
    func step(downbeat: Int) -> Step {
        let starting = downbeat - 1 - countInBars
        let ending = starting - 1
        let record = (ending >= 0 && ending < totalReps) ? ending : nil
        if starting >= 0 && starting < totalReps {
            return Step(recordRep: record, startRep: starting, finished: false)
        }
        return Step(recordRep: record, startRep: nil, finished: starting >= totalReps)
    }
}

/// The chord targeted on each rep — alternating the two drill chords, so you practice
/// the change in both directions (A→B and B→A).
func transitionSequence(from a: Chord, to b: Chord, reps: Int) -> [Chord] {
    (0..<reps).map { $0 % 2 == 0 ? a : b }
}

/// One graded bar of the drill.
struct RepResult: Identifiable {
    let id: Int
    let chord: Chord
    let previous: Chord?
    let axes: ScoreAxes
}
