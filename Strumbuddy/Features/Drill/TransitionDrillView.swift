import SwiftUI

/// Guided transition drill: change between two chords in time with the metronome.
/// Grades each bar (accuracy + cleanliness + timing) and records transition
/// observations to the coach — the data that makes credit assignment real.
struct TransitionDrillView: View {
    @StateObject private var session: DrillSession
    private let engine: AudioEngine

    init(metronome: Metronome, engine: AudioEngine, coach: Coach,
         from: Chord = .c, to: Chord = .g) {
        self.engine = engine
        _session = StateObject(wrappedValue: DrillSession(metronome: metronome, engine: engine,
                                                          coach: coach, from: from, to: to))
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
        .task { await engine.start() }
        .onDisappear { session.stop(); engine.stop() }
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
                }

                Stepper("Reps: \(session.totalReps)", value: $session.totalReps, in: 4...16, step: 2)

                Button("Start") { session.start() }
                    .buttonStyle(.borderedProminent)
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
            Text("Nice work!").font(.title).bold()
            if let s = session.summary {
                summaryBar("Accuracy", s.accuracy)
                summaryBar("Cleanliness", s.cleanliness)
                summaryBar("Timing", s.timing)
            }
            HStack(spacing: Theme.Spacing.l) {
                Button("Again") { session.start() }.buttonStyle(.borderedProminent)
            }
            Spacer()
        }
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
