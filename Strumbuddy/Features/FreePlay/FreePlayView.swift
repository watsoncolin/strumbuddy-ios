import SwiftUI

/// Free play (design-doc §3 mode 3). For v0.1 it hosts the two live audio tools —
/// the Tuner and the Chord Check trainer — under a segmented control. This screen
/// owns the engine's start/stop so the child tools just read it (avoids navigation
/// lifecycle races on the shared engine). In v2 this becomes bring-your-own-song.
struct FreePlayView: View {
    @EnvironmentObject private var env: AppEnvironment

    enum Tool: String, CaseIterable, Identifiable {
        case tuner = "Tuner"
        case chords = "Chords"
        case metronome = "Metro"
        var id: String { rawValue }
    }
    @State private var tool: Tool = .tuner

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                Picker("Tool", selection: $tool) {
                    ForEach(Tool.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch tool {
                case .tuner:     TunerView(engine: env.audioEngine)
                case .chords:    ChordCheckView(engine: env.audioEngine, coach: env.coach)
                case .metronome: MetronomeView(metronome: env.metronome)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Tuner & Chords")
            .navigationBarTitleDisplayMode(.inline)
            .task { await env.audioEngine.start() }
            .onDisappear { env.audioEngine.stop() }
            .onChange(of: tool) { newTool in
                // Leaving chords clears scoring; the Chord Check view also manages this.
                if newTool != .chords { env.audioEngine.setTargetChord(nil) }
            }
        }
    }
}

#Preview {
    FreePlayView()
        .environmentObject(AppEnvironment())
}
