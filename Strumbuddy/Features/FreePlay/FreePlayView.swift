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
            .navigationTitle("Tuner")
            .task { await env.audioEngine.start() }
            .onDisappear { env.audioEngine.stop() }
        }
    }
}

#Preview {
    FreePlayView()
        .environmentObject(AppEnvironment())
}
