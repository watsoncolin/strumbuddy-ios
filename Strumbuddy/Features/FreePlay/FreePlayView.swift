import SwiftUI

/// Free play (design-doc §3 mode 3): pick something and play, scoring turned down.
/// In v2 this becomes the home for bring-your-own-song. For v0.1 it hosts the live
/// tuner — the simplest end-to-end exercise of the audio engine.
struct FreePlayView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                TunerView(engine: env.audioEngine)
                Text("Free play and bring-your-own-song land here in v2.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Free Play")
            .task { await env.audioEngine.start() }
            .onDisappear { env.audioEngine.stop() }
        }
    }
}

/// Live chromatic tuner — reads the engine's monophonic fundamental (design-doc §4).
struct TunerView: View {
    @ObservedObject var engine: AudioEngine

    private static let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

    /// Nearest note name + cents offset for the detected fundamental.
    private var reading: (note: String, cents: Int)? {
        guard let f = engine.fundamental, f > 0 else { return nil }
        let midi = 69 + 12 * log2(f / 440)
        let rounded = midi.rounded()
        let cents = Int(((midi - rounded) * 100).rounded())
        let name = Self.names[((Int(rounded) % 12) + 12) % 12]
        return (name, cents)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            switch engine.state {
            case .denied:
                Label("Microphone access needed", systemImage: "mic.slash")
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
            default:
                if let r = reading {
                    Text(r.note)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                    Text(centsLabel(r.cents))
                        .font(.title3)
                        .foregroundStyle(color(forCents: r.cents))
                } else {
                    Text("—").font(.system(size: 72, weight: .bold, design: .rounded))
                    Text("Play a string").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func centsLabel(_ cents: Int) -> String {
        if abs(cents) <= 5 { return "In tune" }
        return cents > 0 ? "\(cents)¢ sharp" : "\(-cents)¢ flat"
    }

    private func color(forCents cents: Int) -> Color {
        abs(cents) <= 5 ? Theme.clean : Theme.shaky
    }
}

#Preview {
    FreePlayView()
        .environmentObject(AppEnvironment())
}
