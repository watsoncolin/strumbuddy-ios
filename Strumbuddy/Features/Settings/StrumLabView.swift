import SwiftUI

/// Strum lab — the Strumming spike's on-device gate (wiki: Strumming). Measures the
/// new `StrumOnsetDetector` on a real guitar: 8 down-strums, then 8 up-strums, and
/// reports how many were found and how often the direction call was right. The raw
/// cues export as CSV so the classifier can be re-tuned on real playing.
struct StrumLabView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        StrumLab(engine: env.audioEngine)
    }
}

private struct StrumLab: View {
    @ObservedObject var engine: AudioEngine

    private enum Step: Equatable { case intro, downs, ups, results }
    private struct Sample { let label: StrumOnsetDetector.Direction; let strum: AudioEngine.DetectedStrum }

    @State private var step: Step = .intro
    @State private var samples: [Sample] = []
    @State private var stepStart = Date()

    private let target = 8
    /// The gate from the plan: direction is only graded if it's at least this accurate.
    private let gate = 0.85

    var body: some View {
        List {
            switch step {
            case .intro:   intro
            case .downs:   collecting(.down)
            case .ups:     collecting(.up)
            case .results: results
            }
        }
        .navigationTitle("Strum lab")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            engine.detectStrums = true
            await engine.start()
        }
        .onDisappear {
            engine.detectStrums = false
            engine.stop()
        }
        .onChange(of: engine.strum?.id) { _ in record() }
    }

    // MARK: Steps

    private var intro: some View {
        Section {
            Text("Helps tune strum detection on your guitar. Hold an Em chord and strum slowly and evenly — about one strum a second.")
            Text("First 8 strums **down only**, then 8 **up only**. Take your time; tap Next when you've done 8.")
                .foregroundStyle(.secondary)
            Button("Start") { begin(.downs) }.buttonStyle(.borderedProminent)
        } footer: {
            Text("Beta — measurements only. Nothing here affects your progress.")
        }
    }

    private func collecting(_ dir: StrumOnsetDetector.Direction) -> some View {
        let mine = samples.filter { $0.label == dir }
        return Section {
            Text(dir == .down ? "Strum **down** 8 times" : "Now strum **up** 8 times")
                .font(.title3)
            HStack {
                Text("Detected").foregroundStyle(.secondary)
                Spacer()
                Text("\(mine.count)").font(.title2).bold().monospacedDigit()
            }
            strip(mine)
            Button(dir == .down ? "Next: up-strums" : "See results") {
                if dir == .down { begin(.ups) } else { step = .results }
            }
            .buttonStyle(.borderedProminent)
            Button("Redo this step") { samples.removeAll { $0.label == dir }; stepStart = Date() }
                .tint(.secondary)
        }
    }

    private var results: some View {
        let downs = samples.filter { $0.label == .down }
        let ups = samples.filter { $0.label == .up }
        let right = samples.filter { $0.strum.onset.direction == $0.label }.count
        let accuracy = samples.isEmpty ? 0 : Double(right) / Double(samples.count)
        return Group {
            Section("Found") {
                LabeledContent("Down-strums", value: "\(downs.count) of \(target)")
                LabeledContent("Up-strums", value: "\(ups.count) of \(target)")
            }
            Section {
                LabeledContent("Down called down", value: "\(downs.filter { $0.strum.onset.direction == .down }.count)/\(downs.count)")
                LabeledContent("Up called up", value: "\(ups.filter { $0.strum.onset.direction == .up }.count)/\(ups.count)")
                LabeledContent("Overall", value: "\(Int((accuracy * 100).rounded()))%")
            } header: {
                Text("Direction")
            } footer: {
                Text(accuracy >= gate
                     ? "Above the \(Int(gate * 100))% bar — direction could be graded."
                     : "Below the \(Int(gate * 100))% bar — lessons would grade rhythm only.")
            }
            Section {
                ShareLink(item: csv, preview: SharePreview("strum-lab.csv")) {
                    Label("Share measurements (CSV)", systemImage: "square.and.arrow.up")
                }
                Button("Run again") { samples = []; step = .intro }
            }
        }
    }

    /// One chip per detected strum: the call, tinted by whether it matched.
    private func strip(_ list: [Sample]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(list.enumerated()), id: \.offset) { _, s in
                    let ok = s.strum.onset.direction == s.label
                    Image(systemName: s.strum.onset.direction == .down ? "arrow.down" : "arrow.up")
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .background((ok ? Theme.clean : Theme.shaky).opacity(0.18), in: Circle())
                        .foregroundStyle(ok ? Theme.clean : Theme.shaky)
                        .accessibilityLabel("Detected \(s.strum.onset.direction.rawValue)")
                }
            }
        }
    }

    // MARK: Logic

    private func begin(_ s: Step) {
        stepStart = Date()
        step = s
    }

    private func record() {
        guard let strum = engine.strum, strum.time >= stepStart else { return }
        switch step {
        case .downs: samples.append(Sample(label: .down, strum: strum))
        case .ups:   samples.append(Sample(label: .up, strum: strum))
        default:     break
        }
    }

    private var csv: String {
        let t0 = samples.first?.strum.time ?? Date()
        let rows = samples.map { s -> String in
            let o = s.strum.onset
            return [String(format: "%.3f", s.strum.time.timeIntervalSince(t0)), s.label.rawValue,
                    o.direction.rawValue, String(format: "%.3f", o.directionConfidence),
                    String(format: "%.4f", o.bassShare), String(format: "%.4f", o.bassAttack),
                    String(format: "%.2f", o.strength)].joined(separator: ",")
        }
        return (["seconds,label,detected,confidence,bass_share,bass_attack,strength"] + rows)
            .joined(separator: "\n")
    }
}
