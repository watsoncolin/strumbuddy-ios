import SwiftUI

/// Guided transition drill: change between two chords in time with the metronome.
/// Grades each bar (accuracy + cleanliness + timing) and records transition
/// observations to the coach — the data that makes credit assignment real.
struct TransitionDrillView: View {
    @StateObject private var session: DrillSession
    private let engine: AudioEngine
    private let coach: Coach
    private let metronome: Metronome
    /// Fired once when the drill finishes — lets the daily session auto-advance.
    private let onComplete: (() -> Void)?
    /// When false, a parent (the daily-session runner) owns the engine start/stop.
    private let ownsEngine: Bool

    /// `bpm` nil = the tempo ladder's next rung for this change.
    init(metronome: Metronome, engine: AudioEngine, coach: Coach,
         from: Chord = .c, to: Chord = .g, bpm: Int? = nil,
         ownsEngine: Bool = true, onComplete: (() -> Void)? = nil) {
        self.engine = engine
        self.coach = coach
        self.metronome = metronome
        self.onComplete = onComplete
        self.ownsEngine = ownsEngine
        _session = StateObject(wrappedValue: DrillSession(metronome: metronome, engine: engine,
                                                          coach: coach, from: from, to: to,
                                                          bpm: bpm ?? coach.suggestedBPM(from: from, to: to),
                                                          ownsEngineTarget: ownsEngine))
    }

    var body: some View {
        Group {
            switch session.phase {
            case .setup:                 setupView
            case .countIn, .playing:     runningView
            case .finished:              summaryView
            }
        }
        .padding()
        .navigationTitle("Transition Drill")
        .navigationBarTitleDisplayMode(.inline)
        .task { if ownsEngine { await engine.start() } }
        .onDisappear { session.stop(); if ownsEngine { engine.stop() } }
        .onChange(of: session.phase) { if $0 == .finished { onComplete?() } }
        // Picking a different change re-reads its ladder rung.
        .onChange(of: session.fromChord) { _ in climbToLadder() }
        .onChange(of: session.toChord) { _ in climbToLadder() }
    }

    // MARK: Setup

    private var setupView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text("Take a moment to find both shapes, then Start.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Diagrams shown up front so you can rehearse the two shapes first.
                HStack(alignment: .top, spacing: Theme.Spacing.l) {
                    chordColumn("From", selection: $session.fromChord)
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.xl)
                    chordColumn("To", selection: $session.toChord)
                }

                VStack {
                    Text("\(session.bpm) BPM").font(.headline)
                    Slider(value: Binding(get: { Double(session.bpm) },
                                          set: { session.bpm = Int($0) }), in: 40...160, step: 1)
                    Text(ladderCaption).font(.caption).foregroundStyle(.secondary)
                }

                Stepper("Reps: \(session.totalReps)", value: $session.totalReps, in: 4...16, step: 2)

                Button("Start") { session.start() }
                    .buttonStyle(.borderedProminent)

                NavigationLink {
                    CalibrationView(engine: engine, metronome: metronome)
                } label: {
                    Label("Calibrate timing", systemImage: "slider.horizontal.3").font(.subheadline)
                }
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    private func chordColumn(_ label: String, selection: Binding<Chord>) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Menu(selection.wrappedValue.displayName) {
                ForEach(Chord.allCases) { chord in
                    Button(chord.displayName) { selection.wrappedValue = chord }
                }
            }
            .font(.title3).bold()
            ChordDiagramView(chord: selection.wrappedValue)
                .frame(width: 110, height: 150)
            ChordPreviewButton(chord: selection.wrappedValue)
        }
    }

    // MARK: Running

    private var runningView: some View {
        VStack(spacing: Theme.Spacing.l) {
            beatDots
            if session.phase == .countIn {
                Text("Get ready…").font(.title2).foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else if let chord = session.currentChord {
                Text("Rep \(session.currentRep + 1) of \(session.totalReps)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(chord.displayName).font(.system(size: 56, weight: .bold, design: .rounded))
                ChordDiagramView(chord: chord).frame(width: 130, height: 168)
                Spacer()
            }
            Button("Stop") { session.stop() }.tint(.secondary)
        }
    }

    private var beatDots: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(1...4, id: \.self) { beat in
                Circle()
                    .fill(session.beatInBar == beat ? (beat == 1 ? Theme.accent : Theme.clean)
                                                    : Color.secondary.opacity(0.2))
                    .frame(width: 16, height: 16)
            }
        }
    }

    // MARK: Summary

    private var summaryView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Text(cleared ? "Cleared \(session.bpm) bpm!" : "Nice work!").font(.title).bold()
            if let s = session.summary {
                summaryBar("Accuracy", s.accuracy)
                summaryBar("Cleanliness", s.cleanliness)
                summaryBar("Timing", s.timing)
            }
            Text(cleared ? "That change is clean at this tempo. Ready for the next rung?"
                         : "Clean it up here before speeding up — reps at a tempo you can manage build it fastest.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: Theme.Spacing.l) {
                if cleared {
                    Button("Again") { session.start() }.buttonStyle(.bordered)
                    Button("Next rung: \(nextRung) bpm") {
                        session.bpm = nextRung
                        session.start()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Again") { session.start() }.buttonStyle(.borderedProminent)
                }
            }
            Spacer()
        }
    }

    // MARK: Tempo ladder

    /// This run averaged clean (the same bar the ladder uses to clear a tempo).
    private var cleared: Bool {
        guard !session.results.isEmpty else { return false }
        let mean = session.results.map(\.axes.overall).reduce(0, +) / Double(session.results.count)
        return mean >= TempoLadder.clearScore
    }

    private var nextRung: Int { min(session.bpm + TempoLadder.step, TempoLadder.ceiling) }

    private var ladderCaption: String {
        if let best = coach.bestClearedBPM(from: session.fromChord, to: session.toChord) {
            return "Clean at \(best) bpm so far — next rung \(min(best + TempoLadder.step, TempoLadder.ceiling))."
        }
        return "Get it clean at \(TempoLadder.start) bpm, then StrumBuddy speeds it up."
    }

    private func climbToLadder() {
        session.bpm = coach.suggestedBPM(from: session.fromChord, to: session.toChord)
    }

    private func summaryBar(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(value >= 0.8 ? Theme.clean : (value >= 0.5 ? Theme.shaky : Theme.missed))
        }
    }
}
