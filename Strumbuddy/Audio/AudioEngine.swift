import Foundation
import AVFoundation
import Combine

/// The shared audio engine (design-doc §4). Captures the mic via AVAudioEngine and
/// fans the buffer out to two analysis paths:
///
///   • Monophonic path (`Tuner` / pitch) → single fundamental → tuner, riffs, melody.
///   • Polyphonic path (`Chromagram` → `ChordDetector`) → chord identity + cleanliness.
///
/// Both run off the SAME input tap. v0.1 uses AVFoundation + Accelerate only — no
/// third-party audio deps (see §4 licensing note).
@MainActor
final class AudioEngine: ObservableObject {
    enum State: Equatable { case idle, running, denied, failed(String) }

    @Published private(set) var state: State = .idle
    /// Latest detected fundamental (Hz), or nil when no clear pitch. Drives the tuner.
    @Published private(set) var fundamental: Double?
    /// Latest chromagram (12 pitch-class energies, normalized). Drives chord detection.
    @Published private(set) var chroma: [Float] = Array(repeating: 0, count: 12)

    private let engine = AVAudioEngine()
    private let chromagram = Chromagram()
    private let pitchTracker = PitchTracker()

    /// Request mic permission and start capturing.
    func start() async {
        guard await Self.requestMicPermission() else { state = .denied; return }
        do {
            try configureSession()
            try installTapAndStart()
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        state = .idle
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    private func installTapAndStart() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let pitch = self.pitchTracker.detect(buffer)
            let chroma = self.chromagram.compute(buffer)
            Task { @MainActor in
                self.fundamental = pitch
                self.chroma = chroma
            }
        }
        engine.prepare()
        try engine.start()
    }

    private static func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in cont.resume(returning: granted) }
            }
        }
    }
}
