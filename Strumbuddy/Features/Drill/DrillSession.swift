import Foundation
import Combine

/// Drives the transition drill in real time: subscribes to the metronome, switches
/// the target chord each bar (via the pure `DrillSchedule`), grades each bar's best
/// strum (accuracy + cleanliness from the engine, timing from `BeatClock`), and
/// records a transition observation to the coach.
@MainActor
final class DrillSession: ObservableObject {
    enum Phase: Equatable { case setup, countIn, playing, finished }

    @Published var fromChord: Chord = .c
    @Published var toChord: Chord = .g
    @Published var bpm: Int = 60
    @Published var totalReps: Int = 8

    @Published private(set) var phase: Phase = .setup
    @Published private(set) var currentChord: Chord?
    @Published private(set) var currentRep = 0
    @Published private(set) var beatInBar = 0
    @Published private(set) var results: [RepResult] = []

    private let metronome: Metronome
    private let engine: AudioEngine
    private let coach: Coach
    private let scoring = ScoringService()

    private var sequence: [Chord] = []
    private var schedule = DrillSchedule(totalReps: 0)
    private var downbeat = 0
    private var cancellable: AnyCancellable?

    init(metronome: Metronome, engine: AudioEngine, coach: Coach,
         from: Chord = .c, to: Chord = .g, bpm: Int = 60) {
        self.metronome = metronome
        self.engine = engine
        self.coach = coach
        self.fromChord = from
        self.toChord = to
        self.bpm = bpm
    }

    /// Average per-axis score across recorded reps, for the summary.
    var summary: (accuracy: Double, cleanliness: Double, timing: Double)? {
        guard !results.isEmpty else { return nil }
        func avg(_ value: (RepResult) -> Double) -> Double {
            results.map(value).reduce(0, +) / Double(results.count)
        }
        return (avg { $0.axes.accuracy }, avg { $0.axes.cleanliness }, avg { $0.axes.timing })
    }

    func start() {
        sequence = transitionSequence(from: fromChord, to: toChord, reps: totalReps)
        schedule = DrillSchedule(totalReps: totalReps)
        results = []
        currentRep = 0
        currentChord = nil
        downbeat = 0
        phase = .countIn
        metronome.bpm = bpm
        engine.setTargetChord(nil)
        cancellable = metronome.$beatInBar.sink { [weak self] beat in
            guard let self else { return }
            self.beatInBar = beat
            if beat == 1 { self.onDownbeat() }
        }
        metronome.start()
    }

    func stop() {
        cancellable = nil
        metronome.stop()
        engine.setTargetChord(nil)
        if phase != .finished { phase = .setup }
    }

    private func onDownbeat() {
        downbeat += 1
        let step = schedule.step(downbeat: downbeat)
        if let rep = step.recordRep { recordRep(rep) }
        if let start = step.startRep {
            phase = .playing
            currentRep = start
            currentChord = sequence[start]
            engine.setTargetChord(sequence[start])
        }
        if step.finished { finish() }
    }

    /// Grade the bar that just ended from the engine's peak-hold best + landing time.
    private func recordRep(_ index: Int) {
        let chord = sequence[index]
        let previous = index > 0 ? sequence[index - 1] : nil
        let best = engine.targetScore
        let axes = ScoreAxes(
            accuracy: best?.confidence ?? 0,
            cleanliness: best?.cleanliness ?? 0,
            timing: timingScore())
        results.append(RepResult(id: index, chord: chord, previous: previous, axes: axes))

        let observation = scoring.observation(
            for: chord, previous: previous, axes: axes,
            context: .init(isolation: .inSequence, bpm: bpm, source: .practice),
            now: Date())
        coach.record(observation)
    }

    private func timingScore() -> Double {
        guard let landed = engine.targetScoreTime, let start = metronome.startTime else { return 0 }
        return metronome.clock.alignment(elapsed: landed.timeIntervalSince(start))
    }

    private func finish() {
        cancellable = nil
        metronome.stop()
        engine.setTargetChord(nil)
        currentChord = nil
        phase = .finished
    }
}
