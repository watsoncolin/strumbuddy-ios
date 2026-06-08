import SwiftUI
import UniformTypeIdentifiers

/// Debug harness for BYO-song (v2): pick an audio file you own, run the offline
/// `ChordRecognizer` on it, and inspect the recovered chord timeline + capo
/// suggestion — to measure real-mix accuracy on a device. Beta / dev tool.
struct AnalyzeView: View {
    @State private var phase: Phase = .idle
    @State private var picking = false
    @State private var tier: DifficultyTier = .campfire
    @State private var loop = false
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var synth = SynthPlayer()

    enum Phase { case idle, listening, analyzing, done(Outcome), failed(String) }
    struct Outcome {
        let timeline: [TimedChord]
        let suggestion: CapoSimplifier.Suggestion
        let chords: [ChordSymbol]
    }

    var body: some View {
        Group {
            switch phase {
            case .idle:               idle
            case .listening:          listening
            case .analyzing:          ProgressView("Analyzing…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .done(let outcome):  results(outcome)
            case .failed(let msg):    failure(msg)
            }
        }
        .navigationTitle("Analyze a song")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url): analyze(url)
            case .failure(let error): phase = .failed(error.localizedDescription)
            }
        }
        .onChange(of: recorder.seconds) { secs in
            if case .listening = phase, secs >= recorder.maxSeconds { finishListening() }
        }
        .onDisappear { synth.stop() }
    }

    private let demos: [(label: String, resource: String)] = [
        ("C · G · Am · F", "demo_cgamf"),
        ("Em · D", "demo_emd"),
        ("G · C · G · D", "demo_gcd"),
    ]

    private var idle: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 52)).foregroundStyle(Theme.accent)
            Text("Pick an audio file you own. Strumbuddy works out the chords (beta).")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Choose audio file") { picking = true }
                .buttonStyle(.borderedProminent)
            Button { listen() } label: {
                Label("Listen (play a song near your phone)", systemImage: "mic")
            }
            .buttonStyle(.bordered)
            Text("Best on sparse, slow songs; full mixes are hit-or-miss. First 90s analyzed.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

            Divider().padding(.vertical, Theme.Spacing.s)

            Text("Or try a demo (synth)").font(.caption).foregroundStyle(.secondary)
            ForEach(demos, id: \.resource) { demo in
                if let url = Bundle.main.url(forResource: demo.resource, withExtension: "wav") {
                    Button(demo.label) { analyze(url) }.buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func results(_ outcome: Outcome) -> some View {
        let arrangement = SongSimplifier().arrange(outcome.chords, tier: tier)
        return List {
            Section("Arrangement") {
                Picker("Difficulty", selection: $tier) {
                    ForEach(DifficultyTier.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(arrangement.capo == 0 ? "No capo" : "Capo \(arrangement.capo)").font(.headline)
                Text("Play: " + uniqueShapes(arrangement.shapes).map(\.displayName).joined(separator: " · "))
                Text(tier.blurb).font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Loop (backing track)", isOn: $loop)
                Button {
                    if synth.isPlaying { synth.stop() } else { playback(tierTimeline(outcome)) }
                } label: {
                    Label(synth.isPlaying ? "Stop" : "Hear it (synth guitar)",
                          systemImage: synth.isPlaying ? "stop.fill" : "play.fill")
                }
                Text("Plays the \(tier.rawValue) arrangement — check by ear, or loop it and jam along.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .onChange(of: tier) { _ in
                if synth.isPlaying { playback(tierTimeline(outcome)) }  // restart with new tier
            }
            Section("Chords found (\(outcome.chords.count))") {
                Text(outcome.chords.map(\.displayName).joined(separator: " · "))
            }
            Section("Timeline") {
                ForEach(Array(outcome.timeline.enumerated()), id: \.offset) { _, tc in
                    HStack {
                        Text(timestamp(tc.start)).monospacedDigit().foregroundStyle(.secondary)
                        Text(tc.symbol.displayName).bold()
                    }
                }
            }
            Section {
                Button("Analyze another") { phase = .idle }
            }
        }
    }

    private var listening: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "waveform")
                .font(.system(size: 52)).foregroundStyle(Theme.accent)
            Text("Listening…").font(.title2).bold()
            Text(String(format: "%.0fs", recorder.seconds))
                .font(.title3).monospacedDigit().foregroundStyle(.secondary)
            ProgressView(value: min(Double(recorder.level) * 6, 1))
                .frame(maxWidth: 220)
            Text("Play the song near your phone, then stop.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Stop & analyze") { finishListening() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Theme.shaky)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Try another file") { phase = .idle }
        }
        .padding()
    }

    private func analyze(_ url: URL) {
        phase = .analyzing
        Task {
            do {
                let (samples, sampleRate) = try await Task.detached(priority: .userInitiated) { () -> ([Float], Double) in
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try AudioFileLoader.loadMono(url: url)
                }.value
                await runRecognition(samples: samples, sampleRate: sampleRate)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func listen() {
        Task {
            await recorder.start()
            switch recorder.status {
            case .recording:        phase = .listening
            case .denied:           phase = .failed("Microphone access needed — enable it in Settings.")
            case .failed(let msg):  phase = .failed(msg)
            case .idle:             break
            }
        }
    }

    private func finishListening() {
        let (samples, sampleRate) = recorder.stop()
        Task { await runRecognition(samples: samples, sampleRate: sampleRate) }
    }

    /// The detected timeline remapped to how the chosen tier actually sounds.
    private func tierTimeline(_ outcome: Outcome) -> [TimedChord] {
        let sounding = SongSimplifier().soundingChords(outcome.chords, tier: tier)
        var map: [ChordSymbol: ChordSymbol] = [:]
        for (i, chord) in outcome.chords.enumerated() where i < sounding.count { map[chord] = sounding[i] }
        return outcome.timeline.map {
            TimedChord(symbol: map[$0.symbol] ?? $0.symbol, start: $0.start, end: $0.end)
        }
    }

    /// Synthesize and play back a timeline (off-main render); loops if the toggle is on.
    private func playback(_ timeline: [TimedChord]) {
        let shouldLoop = loop
        Task {
            let samples = await Task.detached(priority: .userInitiated) {
                ChordSynth().render(timeline, sampleRate: 44_100)
            }.value
            synth.play(samples, sampleRate: 44_100, loop: shouldLoop)
        }
    }

    /// Shared: recognize → simplify → show. Heavy work runs off the main actor.
    private func runRecognition(samples: [Float], sampleRate: Double) async {
        phase = .analyzing
        let outcome = await Task.detached(priority: .userInitiated) { () -> Outcome in
            let timeline = ChordRecognizer().recognize(samples, sampleRate: Float(sampleRate))
            var seen = Set<ChordSymbol>()
            let chords = timeline.map(\.symbol).filter { seen.insert($0).inserted }
            let suggestion = CapoSimplifier().suggest(for: chords)
            return Outcome(timeline: timeline, suggestion: suggestion, chords: chords)
        }.value
        phase = .done(outcome)
    }

    private func uniqueShapes(_ shapes: [ChordSymbol]) -> [ChordSymbol] {
        var seen = Set<ChordSymbol>()
        return shapes.filter { seen.insert($0).inserted }
    }

    private func timestamp(_ seconds: Double) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
