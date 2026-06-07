import Foundation
import AVFoundation
import Accelerate
import Combine

/// The shared audio engine (design-doc §4). Captures the mic via AVAudioEngine and
/// fans ONE sample buffer out to two analysis paths:
///
///   • Monophonic path (`PitchDetector`) → single fundamental → tuner, riffs, melody.
///   • Polyphonic path (`Chromagram` → `ChordDetector`) → chord identity + cleanliness.
///
/// v0.1 uses AVFoundation + Accelerate only — no third-party audio deps (§4).
@MainActor
final class AudioEngine: ObservableObject {
    enum State: Equatable { case idle, running, denied, failed(String) }

    /// Minimum YIN clarity for a frame to count as a real pitch detection (vs. noise).
    private static let minClarity = 0.5
    /// RMS above which a buffer is treated as "actively playing" (gates chord scoring).
    /// Kept fairly low so normal-volume strumming registers, not just loud playing.
    private static let playingRMS: Float = 0.006

    // Monophonic outputs (tuner).
    @Published private(set) var state: State = .idle
    /// Latest smoothed fundamental (Hz), or nil when no clear pitch.
    @Published private(set) var fundamental: Double?
    /// Clarity 0…1 for the latest pitch — gates the tuner readout.
    @Published private(set) var clarity: Double = 0

    // Polyphonic outputs (chords).
    /// Latest chromagram (12 normalized pitch-class energies). Exposed for debugging.
    @Published private(set) var chroma: [Float] = Array(repeating: 0, count: 12)
    /// Smoothed score against `targetChord` — chord identity, cleanliness, per-string
    /// quality. Nil when no target is set or nothing is being played.
    @Published private(set) var targetScore: ChordDetector.Result?

    /// The chord the user is currently trying to play. Set by the UI; nil = no scoring.
    var targetChord: Chord?

    private let engine = AVAudioEngine()
    private let chromagram = Chromagram()
    private let chordDetector = ChordDetector()
    // The following live on the audio thread, keeping state across buffers.
    private let pitchSmoother = PitchSmoother()
    private let chordScoreSmoother = ChordScoreSmoother()

    /// Request mic permission and start capturing.
    func start() async {
        guard state != .running else { return }
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
        pitchSmoother.reset()
        chordScoreSmoother.reset()
        fundamental = nil
        clarity = 0
        targetScore = nil
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
        let sampleRate = format.sampleRate

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self,
                  let channel = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))

            // Energy gate (shared by both paths).
            var rms: Float = 0
            vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
            let energetic = rms >= Self.playingRMS

            // Monophonic: pitch → smoother. Only confident frames count; the rest are
            // absorbed by the smoother's hold so a stable note doesn't blink out.
            let pitch = PitchDetector(sampleRate: sampleRate).detect(samples)
            let confident = (pitch?.clarity ?? 0) >= Self.minClarity ? pitch : nil
            let smoothedPitch = self.pitchSmoother.push(confident?.frequency)

            // Polyphonic: chroma → score against the target chord (if any) → smoother.
            let chroma = self.chromagram.compute(samples, sampleRate: Float(sampleRate))
            let rawScore = self.targetChord.map { self.chordDetector.score($0, chroma) }
            let score = self.chordScoreSmoother.push(rawScore, energetic: energetic)

            Task { @MainActor in
                self.fundamental = smoothedPitch
                if let confident { self.clarity = confident.clarity }
                self.chroma = chroma
                self.targetScore = score
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
