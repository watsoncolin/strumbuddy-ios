import SwiftUI

/// Live chord trainer — the v0.1 showcase of the app's differentiator (design-doc
/// §2, §4): pick a target chord, strum, and see not just "right/wrong" but per-note
/// clean / muted / buzzing feedback plus accuracy & cleanliness.
///
/// Takes the engine as an injected `@ObservedObject` so it observes the live score;
/// the parent owns the engine's start/stop lifecycle.
struct ChordCheckView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var coach: Coach
    @State private var target: Chord = .em

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            chordPicker
            ChordDiagramView(chord: target)
                .frame(width: 130, height: 168)
            scoreDisplay
            Spacer()
        }
        .onAppear { engine.targetChord = target }
        .onChange(of: target) { engine.targetChord = $0 }
        .onDisappear { engine.targetChord = nil }
        // Each completed strum becomes one observation the coach learns from.
        .onChange(of: engine.finalizedAttempt?.id) { _ in recordAttempt() }
    }

    private func recordAttempt() {
        guard let attempt = engine.finalizedAttempt else { return }
        let r = attempt.result
        let axes = ScoreAxes(accuracy: r.confidence, cleanliness: r.cleanliness, timing: r.confidence)
        let observation = Observation(
            timestamp: Date(),
            implicatedSkills: [.chord(r.chord)],
            context: .init(isolation: .isolated, bpm: nil, source: .practice),
            scores: axes)
        coach.record(observation)
    }

    private var chordPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(Chord.allCases) { chord in
                    Button { target = chord } label: {
                        Text(chord.displayName)
                            .font(.headline)
                            .padding(.vertical, Theme.Spacing.s)
                            .padding(.horizontal, Theme.Spacing.m)
                            .background(target == chord ? Theme.accent : Color.secondary.opacity(0.15),
                                        in: Capsule())
                            .foregroundStyle(target == chord ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
        }
    }

    @ViewBuilder
    private var scoreDisplay: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("Play \(target.displayName)")
                .font(.title2).bold()

            if let score = engine.targetScore {
                axisBar("Accuracy", score.confidence)
                axisBar("Cleanliness", score.cleanliness)
                qualityRow(score)
            } else {
                Text("Strum the chord…")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.xl)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .animation(.easeOut(duration: 0.15), value: engine.targetScore)
    }

    private func axisBar(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1)).tint(barColor(value))
        }
    }

    private func qualityRow(_ score: ChordDetector.Result) -> some View {
        let expected = target.expectedPitchClasses.sorted { $0.rawValue < $1.rawValue }
        let buzzing = score.stringQuality
            .filter { $0.value == .buzzing }.keys
            .sorted { $0.rawValue < $1.rawValue }

        return VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(expected, id: \.self) { pc in
                    notePill(pc.name, quality: score.stringQuality[pc] ?? .muted)
                }
            }
            if !buzzing.isEmpty {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Extra:").font(.caption).foregroundStyle(.secondary)
                    ForEach(buzzing, id: \.self) { pc in
                        notePill(pc.name, quality: .buzzing)
                    }
                }
            }
            if !score.ringingMutedStrings.isEmpty {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Silence:").font(.caption).foregroundStyle(.secondary)
                    ForEach(score.ringingMutedStrings, id: \.self) { s in
                        notePill(ChordShape.stringNames[s], quality: .muted)
                    }
                }
            }
            Text(feedback(score))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func notePill(_ name: String, quality: StringQuality) -> some View {
        Text(name)
            .font(.headline).monospaced()
            .frame(width: 46, height: 46)
            .background(qualityColor(quality).opacity(0.18), in: Circle())
            .overlay(Circle().stroke(qualityColor(quality), lineWidth: 2))
            .foregroundStyle(qualityColor(quality))
    }

    private func feedback(_ score: ChordDetector.Result) -> String {
        let muted = target.expectedPitchClasses
            .filter { score.stringQuality[$0] == .muted }
            .sorted { $0.rawValue < $1.rawValue }
        let clean = score.cleanliness >= 0.9 && muted.isEmpty && score.ringingMutedStrings.isEmpty
        if clean { return "Clean! Every note is ringing." }
        if let s = score.ringingMutedStrings.first {
            return "You're letting the \(ChordShape.stringNames[s]) string (\(ordinal(6 - s))) ring — it should stay silent. Lean a finger against it to mute it."
        }
        if let first = muted.first { return mutedAdvice(for: first) }
        if score.stringQuality.values.contains(.buzzing) {
            return "An extra note is ringing — mute the stray string."
        }
        return "Getting there…"
    }

    /// Map a dead note to the specific string + finger to check (the actionable bit).
    private func mutedAdvice(for pc: PitchClass) -> String {
        guard let loc = locate(pc) else { return "\(pc.name) isn't ringing — check that finger." }
        let stringDesc = "\(loc.name) string (\(ordinal(loc.number)))"
        if loc.open {
            return "Your \(stringDesc) isn't ringing — let it ring out; a finger may be muting it."
        }
        if let finger = loc.finger {
            return "Your \(stringDesc) isn't ringing — press your \(fingerName(finger)) finger down firmer, just behind the fret."
        }
        return "Your \(stringDesc) isn't ringing — press it down firmer."
    }

    /// Which string (and finger) produces `pc` in the current shape. Prefers a
    /// fretted string with a finger, since that's the one to actually press harder.
    private func locate(_ pc: PitchClass) -> (name: String, number: Int, finger: Int?, open: Bool)? {
        let shape = ChordShape.library[target] ?? .unknown
        let candidates = (0..<6).filter { shape.soundingPitchClass(forString: $0) == pc.rawValue }
        let chosen = candidates.first { shape.frets[$0] > 0 } ?? candidates.first
        guard let i = chosen else { return nil }
        return (ChordShape.stringNames[i], 6 - i, shape.fingers[i], shape.frets[i] == 0)
    }

    private func fingerName(_ f: Int) -> String {
        let names = ["index", "middle", "ring", "pinky"]
        return (1...4).contains(f) ? names[f - 1] : "finger \(f)"
    }

    private func ordinal(_ n: Int) -> String {
        [1: "1st", 2: "2nd", 3: "3rd", 4: "4th", 5: "5th", 6: "6th"][n] ?? "\(n)th"
    }

    private func qualityColor(_ q: StringQuality) -> Color {
        switch q {
        case .clean:   return Theme.clean
        case .muted:   return Theme.missed
        case .buzzing: return Theme.shaky
        }
    }

    private func barColor(_ v: Double) -> Color {
        v >= 0.8 ? Theme.clean : (v >= 0.5 ? Theme.shaky : Theme.missed)
    }
}
