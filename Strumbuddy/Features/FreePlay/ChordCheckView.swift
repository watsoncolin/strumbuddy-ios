import SwiftUI

/// Live chord trainer — the v0.1 showcase of the app's differentiator (design-doc
/// §2, §4): pick a target chord, strum, and see not just "right/wrong" but per-note
/// clean / muted / buzzing feedback plus accuracy & cleanliness.
///
/// Takes the engine as an injected `@ObservedObject` so it observes the live score;
/// the parent owns the engine's start/stop lifecycle.
struct ChordCheckView: View {
    @ObservedObject var engine: AudioEngine
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
        if score.cleanliness >= 0.9, muted.isEmpty { return "Clean! Every note is ringing." }
        if let first = muted.first { return "\(first.name) isn't ringing — check that finger." }
        if score.stringQuality.values.contains(.buzzing) {
            return "An extra note is ringing — mute the stray string."
        }
        return "Getting there…"
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
