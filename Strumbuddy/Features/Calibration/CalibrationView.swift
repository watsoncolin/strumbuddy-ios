import SwiftUI

/// Calibrate audio input latency so rhythm grading lines up with what you feel.
/// The metronome runs; you strum on each beat; the readout shows how early/late your
/// strums register. Adjust the slider until on-beat strums read "on time." Saved.
struct CalibrationView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var metronome: Metronome

    @State private var latencyMs: Double = Calibration.inputLatency * 1000
    @State private var lastOffsetMs: Int?

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Text("Strum any string on each beat. Adjust the slider until your strums read “on time.”")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

            beatDots

            readout
                .frame(height: 52)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Input latency: \(Int(latencyMs)) ms").font(.subheadline)
                Slider(value: $latencyMs, in: 0...250, step: 1)
                Text("Reads late? Increase latency. Reads early? Decrease it.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Calibrate timing")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await engine.start()
            metronome.bpm = 80
            metronome.start()
        }
        .onDisappear {
            metronome.stop()
            engine.stop()
            Calibration.inputLatency = latencyMs / 1000
        }
        .onChange(of: latencyMs) { value in
            engine.inputLatency = value / 1000          // live
            Calibration.inputLatency = value / 1000     // persist
        }
        .onChange(of: engine.onset?.id) { _ in updateOffset() }
    }

    @ViewBuilder
    private var readout: some View {
        if let ms = lastOffsetMs {
            let onTime = abs(ms) <= 20
            Text(onTime ? "On time ✓" : (ms > 0 ? "\(ms) ms late" : "\(-ms) ms early"))
                .font(.title).bold()
                .foregroundStyle(onTime ? Theme.clean : Theme.shaky)
        } else {
            Text("strum…").font(.title3).foregroundStyle(.secondary)
        }
    }

    private var beatDots: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(1...4, id: \.self) { beat in
                Circle()
                    .fill(metronome.beatInBar == beat ? (beat == 1 ? Theme.accent : Theme.clean)
                                                      : Color.secondary.opacity(0.2))
                    .frame(width: 14, height: 14)
            }
        }
    }

    private func updateOffset() {
        guard let onset = engine.onset, let start = metronome.startTime else { return }
        let corrected = onset.time.addingTimeInterval(-engine.inputLatency)
        let signed = metronome.clock.signedOffset(elapsed: corrected.timeIntervalSince(start))
        lastOffsetMs = Int((signed * 1000).rounded())
    }
}
