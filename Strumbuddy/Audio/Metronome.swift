import Foundation
import AVFoundation
import Combine

/// Metronome — table stakes (design-doc §6) and the foundation for the rhythm /
/// transition drill. Drives a steady beat with an accented downbeat, both audible
/// (a synthesized click) and visible (`beatInBar`). Beat-grid math lives in the
/// pure `BeatClock` so timing grading is testable.
@MainActor
final class Metronome: ObservableObject {
    @Published var bpm: Int = 60
    @Published private(set) var isRunning = false
    /// 1…beatsPerBar while running, 0 when stopped — drives the visual pulse.
    @Published private(set) var beatInBar = 0

    let beatsPerBar = 4

    /// Monotonic start time (for timing grading against `BeatClock`); nil when stopped.
    private(set) var startTime: Date?
    var clock: BeatClock { BeatClock(bpm: Double(bpm)) }

    private var timer: Timer?
    private var beatCount = 0
    private let click = ClickPlayer()

    func start() {
        stop()
        isRunning = true
        beatCount = 0
        startTime = Date()
        tick()  // sound the downbeat immediately
        let interval = 60.0 / Double(bpm)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        beatInBar = 0
        startTime = nil
    }

    private func tick() {
        let inBar = beatCount % beatsPerBar     // 0…3
        beatInBar = inBar + 1                    // 1…4
        click.play(accent: inBar == 0)
        beatCount += 1
    }
}

/// Plays a short synthesized click through its own audio engine. Two pitches: a
/// higher accent for the downbeat. Kept separate from the mic `AudioEngine`; the
/// click bleeding into the mic is harmless because chord/timing grading keys off
/// detected chords, not raw onsets.
private final class ClickPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let normal: AVAudioPCMBuffer?
    private let accent: AVAudioPCMBuffer?
    private var started = false

    init() {
        let sampleRate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        normal = ClickPlayer.makeClick(frequency: 1_000, sampleRate: sampleRate, format: format)
        accent = ClickPlayer.makeClick(frequency: 1_500, sampleRate: sampleRate, format: format)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(accent useAccent: Bool) {
        ensureStarted()
        guard let buffer = useAccent ? accent : normal else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func ensureStarted() {
        guard !started else { return }
        do {
            try engine.start()
            player.play()
            started = true
        } catch {
            // Leave started=false; a later beat will retry.
        }
    }

    private static func makeClick(frequency: Float, sampleRate: Double,
                                  format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * 0.03)   // 30 ms
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Float(i) / Float(sampleRate)
            let envelope = expf(-t * 80)                    // fast percussive decay
            samples[i] = sinf(2 * .pi * frequency * t) * envelope * 0.6
        }
        return buffer
    }
}
