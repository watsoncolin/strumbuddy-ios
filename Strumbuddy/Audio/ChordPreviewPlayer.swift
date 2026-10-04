import Foundation
import AVFoundation

/// Plays "what this should sound like" — a `GuitarSynth` strum of the shape in the
/// diagram, or a whole song strummed at tempo (`SongRenderer`). Owns a small engine +
/// player node, like the metronome's click, and leaves the mic's `.playAndRecord`
/// session alone so it can play mid-session.
///
/// While a preview rings, the mic engine's scoring is paused (`suppressInput`) —
/// otherwise the phone would hear its own strum and count it as the player's.
@MainActor
final class ChordPreviewPlayer: ObservableObject {
    /// The chord currently sounding, for the button's playing state.
    @Published private(set) var playing: Chord?
    /// The song currently playing and when its first bar starts (after the count-in),
    /// so the chart can follow along.
    @Published private(set) var playingSong: Song.ID?
    @Published private(set) var songBarsStart: Date?
    private(set) var songBPM: Int?

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
            playingSong = nil
            songBarsStart = nil
            playing = chord
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if token == playToken { playing = nil }
        }
    }

    /// Strum the whole song at `bpm` with a one-bar count-in.
    func playSong(_ song: Song, bpm: Int) {
        playToken += 1
        let token = playToken
        let renderer = SongRenderer()
        let chords = song.flatChords
        Task {
            let samples = await Task.detached(priority: .userInitiated) {
                renderer.render(chords, bpm: bpm)
            }.value
            guard token == playToken, let buffer = makeBuffer(samples), startEngine() else { return }
            let length = Double(samples.count) / format.sampleRate
            micEngine.suppressInput(for: length + 0.3)
            player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            if !player.isPlaying { player.play() }
            playing = nil
            playingSong = song.id
            songBPM = bpm
            songBarsStart = Date().addingTimeInterval(renderer.leadIn(bpm: bpm))
            try? await Task.sleep(nanoseconds: UInt64(length * 1_000_000_000))
            if token == playToken { playingSong = nil; songBarsStart = nil }
        }
    }

    /// Stop whatever is sounding and give the mic back.
    func stop() {
        playToken += 1
        player.stop()
        playing = nil
        playingSong = nil
        songBarsStart = nil
        micEngine.suppressInput(for: 0)
    }

    /// Rendered once per chord, off the main thread (the synth is pure).
    private func buffer(for chord: Chord) async -> AVAudioPCMBuffer? {
        if let cached = cache[chord] { return cached }
        let duration = self.duration
        let samples = await Task.detached(priority: .userInitiated) {
            GuitarSynth().strum(chord, duration: duration)
        }.value
        guard let buffer = makeBuffer(samples) else { return nil }
        cache[chord] = buffer
        return buffer
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
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
