import SwiftUI

/// One-minute changes: alternate two chords as many times as you can, cleanly, in
/// 60 seconds. The engine verifies every landing; the count goes in your history
/// and the progress screen charts it.
struct OneMinuteChangesView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        OneMinuteRunner(engine: env.audioEngine, store: env.oneMinute)
    }
}

private struct OneMinuteRunner: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var store: OneMinuteStore

    private enum Phase: Equatable { case setup, countdown(Int), running, finished }

    @State private var first: Chord = .c
    @State private var second: Chord = .g
    @State private var phase: Phase = .setup
    @State private var counter = OneMinuteCounter(first: .c, second: .g)
    @State private var endsAt = Date()
    @State private var remaining = OneMinuteRunner.duration
    @State private var newBest = false
    @State private var runTask: Task<Void, Never>?

    static let duration: TimeInterval = 60

    private var pairKey: String { OneMinuteResult.key(first, second) }

    var body: some View {
        Group {
            switch phase {
            case .setup:            setup
            case .countdown(let n): countdown(n)
            case .running:          running
            case .finished:         finished
            }
        }
        .padding()
        .navigationTitle("One-minute changes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await engine.start() }
        .onDisappear {
            runTask?.cancel()
            engine.setTargetChord(nil)
            engine.stop()
        }
        .onChange(of: engine.finalizedAttempt?.id) { _ in landStrum() }
    }

    // MARK: Setup

    private var setup: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text("Switch between two chords as many times as you can in one minute. Only clean landings count.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(alignment: .top, spacing: Theme.Spacing.l) {
                    chordPicker($first)
                    Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.xl)
                    chordPicker($second)
                }
                if let best = store.best(for: pairKey) {
                    Label("Your best: \(best) changes", systemImage: "trophy")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Button(action: begin) {
                    Label("Start the minute", systemImage: "timer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(first == second)
            }
        }
    }

    private func chordPicker(_ selection: Binding<Chord>) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Menu(selection.wrappedValue.displayName) {
                ForEach(Chord.allCases) { chord in
                    Button(chord.displayName) { selection.wrappedValue = chord }
                }
            }
            .font(.title3).bold()
            ChordDiagramView(chord: selection.wrappedValue).frame(width: 100, height: 130)
        }
    }

    // MARK: Run

    private func countdown(_ n: Int) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("Fingers on \(first.displayName)…").font(.title3).foregroundStyle(.secondary)
            Text("\(n)").font(.system(size: 96, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .frame(maxHeight: .infinity)
    }

    private var running: some View {
        VStack(spacing: Theme.Spacing.l) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: remaining / Self.duration)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(counter.changes)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("changes").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(counter.changes) changes, \(Int(remaining.rounded(.up))) seconds left")

            Text(counter.started ? "Now: \(counter.target.displayName)" : "Strum \(counter.target.displayName) to start")
                .font(.title2).bold()
            ChordDiagramView(chord: counter.target).frame(width: 110, height: 142)
            Spacer()
            Button("Stop") { finish(record: false) }.tint(.secondary)
        }
    }

    private var finished: some View {
        let history = store.history(for: pairKey)
        return ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text("\(counter.changes)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                Text("\(first.displayName) ↔ \(second.displayName) changes in a minute")
                    .font(.headline).foregroundStyle(.secondary)
                if newBest {
                    Label("New personal best!", systemImage: "trophy.fill")
                        .font(.subheadline).foregroundStyle(.orange)
                } else if let best = store.best(for: pairKey) {
                    Text("Your best is \(best).").font(.subheadline).foregroundStyle(.secondary)
                }
                if history.count >= 2 {
                    OneMinuteChart(history: history).frame(height: 180)
                }
                Text("Do this once a day — the number climbs faster than you'd think.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(spacing: Theme.Spacing.l) {
                    Button("Change chords") { phase = .setup }.buttonStyle(.bordered)
                    Button("Go again", action: begin).buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: Logic

    private func begin() {
        runTask?.cancel()
        counter = OneMinuteCounter(first: first, second: second)
        newBest = false
        remaining = Self.duration
        engine.setTargetChord(nil)   // no scoring during the countdown
        runTask = Task { @MainActor in
            for n in stride(from: 3, through: 1, by: -1) {
                withAnimation { phase = .countdown(n) }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            engine.setTargetChord(counter.target)
            endsAt = Date().addingTimeInterval(Self.duration)
            phase = .running
            while !Task.isCancelled {
                remaining = max(0, endsAt.timeIntervalSinceNow)
                if remaining <= 0 { finish(record: true); return }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func landStrum() {
        guard phase == .running, let attempt = engine.finalizedAttempt else { return }
        var next = counter
        if next.strum(attempt.result.chord, confidence: attempt.result.confidence) {
            withAnimation { counter = next }
            engine.setTargetChord(counter.target)
        }
    }

    private func finish(record: Bool) {
        runTask?.cancel()
        engine.setTargetChord(nil)
        if record {
            newBest = store.record(OneMinuteResult(date: Date(), from: first, to: second,
                                                   changes: counter.changes))
            phase = .finished
        } else {
            phase = .setup
        }
    }
}
