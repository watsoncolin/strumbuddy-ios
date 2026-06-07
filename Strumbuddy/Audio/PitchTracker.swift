import Foundation
import AVFoundation

/// Thin AVFoundation wrapper around the pure `PitchDetector` (design-doc §4
/// monophonic path). Extracts samples from a mic buffer and runs YIN detection.
/// All the actual algorithm — and all the testability — lives in `PitchDetector`.
struct PitchTracker {
    func detect(_ buffer: AVAudioPCMBuffer) -> PitchDetector.Result? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return nil }
        let samples = Array(UnsafeBufferPointer(start: channel, count: n))
        return PitchDetector(sampleRate: buffer.format.sampleRate).detect(samples)
    }
}
