import Foundation
import AVFoundation

/// Plays "what this chord should sound like" — a `GuitarSynth` strum of the shape in
/// the diagram. Owns a small engine + player node, like the metronome's click, and
/// leaves the mic's `.playAndRecord` session alone so it can play mid-session.
///
/// While a preview rings, the mic engine's scoring is paused (`suppressInput`) —
/// otherwise the phone would hear its own strum and count it as the player's.
@MainActor
final class ChordPreviewPlayer: ObservableObject {
    /// The chord currently sounding, for the button's playing state.
    @Published private(set) var playing: Chord?

    private let micEngine: AudioEngine
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let duration = 2.6
    private var cache: [Chord: AVAudioPCMBuffer] = [:]
    private var playToken = 0

    init(micEngine: AudioEngine) {
        self.micEngine = micEngine
        let synth = GuitarSynth()
        format = AVAudioFormat(standardFormatWithSampleRate: synth.sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ chord: Chord) {
        playToken += 1
        let token = playToken
        Task {
            guard let buffer = await buffer(for: chord), token == playToken else { return }
            guard startEngine() else { return }
            micEngine.suppressInput(for: duration + 0.3)
            player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            if !player.isPlaying { player.play() }
            playing = chord
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if token == playToken { playing = nil }
        }
    }

    /// Rendered once per chord, off the main thread (the synth is pure).
    private func buffer(for chord: Chord) async -> AVAudioPCMBuffer? {
        if let cached = cache[chord] { return cached }
        let duration = self.duration
        let samples = await Task.detached(priority: .userInitiated) {
            GuitarSynth().strum(chord, duration: duration)
        }.value
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(samples.count))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        cache[chord] = buffer
        return buffer
    }

    private func startEngine() -> Bool {
        // With the mic idle the session may still be the silent-switch-respecting
        // default; use playback so a preview is audible. Never downgrade the mic's
        // .playAndRecord session, or capture would stop.
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try? session.setCategory(.playback)
            try? session.setActive(true)
        }
        if engine.isRunning { return true }
        do { try engine.start(); return true } catch { return false }
    }
}
