import Foundation
import AVFoundation

/// Plays a rendered mono sample buffer once (the synth-guitar reconstruction of an
/// analyzed song). Owns a small engine + player node.
@MainActor
final class SynthPlayer: ObservableObject {
    @Published private(set) var isPlaying = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var attached = false

    func play(_ samples: [Float], sampleRate: Double) {
        stop()
        guard !samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { ptr in
            _ = memcpy(buffer.floatChannelData![0], ptr.baseAddress!, samples.count * MemoryLayout<Float>.size)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        if !attached { engine.attach(player); attached = true }
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do { try engine.start() } catch { return }
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            Task { @MainActor in self?.isPlaying = false }
        }
        player.play()
        isPlaying = true
    }

    func stop() {
        if player.isPlaying { player.stop() }
        if engine.isRunning { engine.stop() }
        isPlaying = false
    }
}
