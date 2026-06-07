import Foundation
import AVFoundation
import Accelerate

/// Monophonic pitch detection (design-doc §4 monophonic path). Returns a single
/// fundamental frequency — powers the tuner and single-note riff/melody work.
///
/// v0.1 stub: a normalized-autocorrelation pitch estimator on the raw buffer.
/// Solid enough for a tuner; revisit (YIN / cepstrum) if accuracy is lacking.
struct PitchTracker {
    /// Minimum clarity (peak autocorrelation) to report a pitch at all.
    var clarityThreshold: Float = 0.3

    func detect(_ buffer: AVAudioPCMBuffer) -> Double? {
        guard let samples = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return nil }
        let sampleRate = buffer.format.sampleRate

        // TODO(audio): replace naive autocorrelation with YIN for robustness.
        let frame = Array(UnsafeBufferPointer(start: samples, count: n))

        // Skip silence.
        var rms: Float = 0
        vDSP_rmsqv(frame, 1, &rms, vDSP_Length(n))
        guard rms > 0.01 else { return nil }

        // Search lag range corresponding to ~80–1000 Hz (guitar range).
        let minLag = Int(sampleRate / 1000)
        let maxLag = min(Int(sampleRate / 80), n - 1)
        guard maxLag > minLag else { return nil }

        var bestLag = -1
        var bestValue: Float = 0
        for lag in minLag...maxLag {
            var sum: Float = 0
            vDSP_dotpr(frame, 1, Array(frame[lag...]), 1, &sum, vDSP_Length(n - lag))
            if sum > bestValue { bestValue = sum; bestLag = lag }
        }

        var energy: Float = 0
        vDSP_dotpr(frame, 1, frame, 1, &energy, vDSP_Length(n))
        let clarity = energy > 0 ? bestValue / energy : 0
        guard bestLag > 0, clarity > clarityThreshold else { return nil }

        return sampleRate / Double(bestLag)
    }
}
