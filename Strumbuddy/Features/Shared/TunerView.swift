import SwiftUI

/// Live chromatic tuner (design-doc §4 monophonic path / §6 table stakes).
/// Reads the engine's smoothed fundamental + clarity and shows note, octave, a
/// cents needle, and which guitar string you're nearest to.
struct TunerView: View {
    @ObservedObject var engine: AudioEngine
    /// Fired once when **every** string has been confirmed in tune — lets the
    /// daily session auto-advance on engine-verified success rather than a manual
    /// "done" tap. When non-nil, the per-string checklist is shown.
    var onInTune: (() -> Void)? = nil
    /// When false, a parent (e.g. the daily-session runner) owns the engine's
    /// start/stop lifecycle, so this view must not tear it down.
    var ownsEngine = true

    @State private var tuneTask: Task<Void, Never>?
    @State private var tuneFired = false
    @State private var tunedStrings: Set<String> = []

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
                    message("Play a string", systemImage: "guitars", detail: "Pluck each string to tune.")
                }
            }
            if onInTune != nil { tuningChecklist }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.12), value: reading?.cents)
        .task { if ownsEngine { await engine.start() } }
        .onDisappear { tuneTask?.cancel(); if ownsEngine { engine.stop() } }
        .onChange(of: reading?.inTune ?? false) { handleTune($0) }
    }

    /// Per-string "tune everything" checklist shown when driving a session block.
    private var tuningChecklist: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Tune each string — \(tunedStrings.count) of \(TunerReading.stringLabels.count)")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: Theme.Spacing.m) {
                ForEach(TunerReading.stringLabels, id: \.self) { label in
                    let done = tunedStrings.contains(label)
                    VStack(spacing: 4) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Theme.clean : .secondary)
                        Text(shortLabel(label)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.m)
    }

    /// "6th (Low E)" → "Low E".
    private func shortLabel(_ l: String) -> String {
        guard let open = l.firstIndex(of: "("), let close = l.firstIndex(of: ")") else { return l }
        return String(l[l.index(after: open)..<close])
    }

    /// Mark the currently-played string tuned once it holds in tune for ~0.7s (so a
    /// fleeting frame doesn't count); fire `onInTune` only once all six are done.
    private func handleTune(_ inTune: Bool) {
        guard onInTune != nil else { return }
        tuneTask?.cancel()
        guard inTune, !tuneFired else { return }
        tuneTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, !tuneFired,
                  let r = TunerReading(frequency: engine.fundamental), r.inTune,
                  let string = r.nearestString else { return }
            tunedStrings.insert(string)
            if tunedStrings.count >= TunerReading.stringLabels.count {
                tuneFired = true
                onInTune?()
            }
        }
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
