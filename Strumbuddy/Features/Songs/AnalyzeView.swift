import SwiftUI
import UniformTypeIdentifiers

/// Debug harness for BYO-song (v2): pick an audio file you own, run the offline
/// `ChordRecognizer` on it, and inspect the recovered chord timeline + capo
/// suggestion — to measure real-mix accuracy on a device. Beta / dev tool.
struct AnalyzeView: View {
    @State private var phase: Phase = .idle
    @State private var picking = false
    @StateObject private var recorder = AudioRecorder()

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
        List {
            Section("Capo suggestion") {
                Text(outcome.suggestion.capo == 0 ? "No capo" : "Capo \(outcome.suggestion.capo)")
                    .font(.headline)
                Text("Play: " + uniqueShapes(outcome.suggestion).map(\.displayName).joined(separator: " · "))
                Text("\(Int(outcome.suggestion.coverage * 100))% playable as open shapes")
                    .font(.caption).foregroundStyle(.secondary)
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

    private func uniqueShapes(_ suggestion: CapoSimplifier.Suggestion) -> [ChordSymbol] {
        var seen = Set<ChordSymbol>()
        return suggestion.shapes.filter { seen.insert($0).inserted }
    }

    private func timestamp(_ seconds: Double) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
