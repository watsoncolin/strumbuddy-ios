import SwiftUI

/// Live chromatic tuner (design-doc §4 monophonic path / §6 table stakes).
/// Reads the engine's smoothed fundamental + clarity and shows note, octave, a
/// cents needle, and which guitar string you're nearest to.
struct TunerView: View {
    @ObservedObject var engine: AudioEngine

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            switch engine.state {
            case .denied:
                message("Microphone access needed", systemImage: "mic.slash",
                        detail: "Enable the mic for Strumbuddy in Settings.")
            case .failed(let msg):
                message("Audio error", systemImage: "exclamationmark.triangle", detail: msg)
            case .idle:
                message("Tuner is off", systemImage: "tuningfork", detail: nil)
            case .running:
                if let reading = reading {
                    readout(reading)
                } else {
                    message("Play a string", systemImage: "guitars", detail: "Pluck one string to tune.")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.12), value: reading?.cents)
        .task { await engine.start() }
        .onDisappear { engine.stop() }
    }

    // MARK: - Readout

    @ViewBuilder
    private func readout(_ r: TunerReading) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(r.noteName)
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .foregroundStyle(r.inTune ? Theme.clean : .primary)
                .contentTransition(.numericText())
            Text("Octave \(r.octave)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        CentsMeter(cents: r.cents)
            .frame(height: 56)
            .padding(.horizontal, Theme.Spacing.l)

        VStack(spacing: Theme.Spacing.xs) {
            Text(r.directionLabel)
                .font(.headline)
                .foregroundStyle(r.inTune ? Theme.clean : Theme.shaky)
            if let string = r.nearestString {
                Text("Nearest string: \(string)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(String(format: "%.1f Hz", r.frequency))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func message(_ title: String, systemImage: String, detail: String?) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, Theme.Spacing.xl)
    }

    private var reading: TunerReading? {
        // The engine + smoother already gate on clarity and hold a decaying note,
        // so a present fundamental means we have something worth showing.
        TunerReading(frequency: engine.fundamental)
    }
}

/// A horizontal cents meter: center is in-tune, indicator slides left (flat) / right (sharp).
private struct CentsMeter: View {
    let cents: Int
    private var inTune: Bool { abs(cents) <= 5 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = geo.size.height / 2
            let clamped = Double(max(-50, min(50, cents)))
            let x = w / 2 + (clamped / 50) * (w / 2)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 8)
                    .position(x: w / 2, y: midY)

                // In-tune zone (±5¢) highlighted in the center.
                Capsule()
                    .fill(Theme.clean.opacity(0.25))
                    .frame(width: w * (10.0 / 100.0), height: 8)
                    .position(x: w / 2, y: midY)

                // Center reference tick.
                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 2, height: 22)
                    .position(x: w / 2, y: midY)

                // Moving indicator.
                Circle()
                    .fill(inTune ? Theme.clean : Theme.shaky)
                    .frame(width: 24, height: 24)
                    .position(x: x, y: midY)
            }
        }
    }
}
