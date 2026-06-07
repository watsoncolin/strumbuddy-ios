import SwiftUI

/// Metronome tool: big BPM readout, a row of beat dots (accented downbeat), tempo
/// control, and start/stop. Restarts cleanly when you change tempo mid-run.
struct MetronomeView: View {
    @ObservedObject var metronome: Metronome

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            VStack(spacing: 0) {
                Text("\(metronome.bpm)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("BPM").font(.caption).foregroundStyle(.secondary)
            }

            beatDots

            Slider(
                value: Binding(get: { Double(metronome.bpm) },
                               set: { metronome.bpm = Int($0) }),
                in: 40...200, step: 1
            )
            .padding(.horizontal, Theme.Spacing.l)

            HStack(spacing: Theme.Spacing.l) {
                Button { metronome.bpm = max(40, metronome.bpm - 5) } label: {
                    Image(systemName: "minus.circle.fill").font(.title)
                }
                Button(metronome.isRunning ? "Stop" : "Start") {
                    metronome.isRunning ? metronome.stop() : metronome.start()
                }
                .buttonStyle(.borderedProminent)
                Button { metronome.bpm = min(200, metronome.bpm + 5) } label: {
                    Image(systemName: "plus.circle.fill").font(.title)
                }
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.l)
        // Apply a tempo change live by restarting the beat loop.
        .onChange(of: metronome.bpm) { _ in if metronome.isRunning { metronome.start() } }
        .onDisappear { metronome.stop() }
    }

    private var beatDots: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(1...metronome.beatsPerBar, id: \.self) { beat in
                Circle()
                    .fill(color(for: beat))
                    .frame(width: 20, height: 20)
                    .scaleEffect(metronome.isRunning && metronome.beatInBar == beat ? 1.3 : 1.0)
                    .animation(.easeOut(duration: 0.08), value: metronome.beatInBar)
            }
        }
    }

    private func color(for beat: Int) -> Color {
        guard metronome.isRunning, metronome.beatInBar == beat else { return .secondary.opacity(0.2) }
        return beat == 1 ? Theme.accent : Theme.clean   // accent the downbeat
    }
}
