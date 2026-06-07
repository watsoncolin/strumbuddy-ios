import Foundation
import Accelerate

/// Pure monophonic pitch detector — the YIN algorithm (de Cheveigné & Kawahara, 2002).
///
/// Deliberately free of AVFoundation so it operates on raw `[Float]` samples and is
/// unit-testable off-device (see `scripts/main.swift`). Powers the tuner and, later,
/// single-note riff/melody work (design-doc §4 monophonic path).
///
/// YIN is chosen over plain autocorrelation because its cumulative-mean-normalized
/// difference function suppresses the octave errors that plague guitar's low strings.
struct PitchDetector {
    var sampleRate: Double

    /// YIN absolute threshold. Lower = stricter (fewer octave errors, more dropouts).
    var threshold: Float = 0.15
    /// Guitar-oriented bounds: low E is 82.4 Hz, high E 329.6 Hz; headroom for melody.
    var minFrequency: Double = 70
    var maxFrequency: Double = 1000
    /// Skip silence below this RMS. Kept low so a decaying plucked note keeps
    /// registering while it's still audibly ringing.
    var minRMS: Float = 0.003

    struct Result: Equatable {
        let frequency: Double
        /// 1 - d'(τ): 1.0 = perfectly periodic, ~0 = noise. Used to gate the readout.
        let clarity: Double
    }

    func detect(_ samples: [Float]) -> Result? {
        let n = samples.count
        let maxTau = min(Int(sampleRate / minFrequency), n - 1)
        let minTau = max(2, Int(sampleRate / maxFrequency))
        let window = n - maxTau
        guard window >= 256, maxTau > minTau else { return nil }

        return samples.withUnsafeBufferPointer { buf -> Result? in
            guard let x = buf.baseAddress else { return nil }

            // Silence gate.
            var rms: Float = 0
            vDSP_rmsqv(x, 1, &rms, vDSP_Length(window))
            guard rms >= minRMS else { return nil }

            // 1) Difference function d(τ) = Σ (x[j] - x[j+τ])², vectorized.
            var d = [Float](repeating: 0, count: maxTau + 1)
            for tau in 1...maxTau {
                var dsq: Float = 0
                vDSP_distancesq(x, 1, x + tau, 1, &dsq, vDSP_Length(window))
                d[tau] = dsq
            }

            // 2) Cumulative mean normalized difference d'(τ).
            var dPrime = [Float](repeating: 1, count: maxTau + 1)
            var runningSum: Float = 0
            for tau in 1...maxTau {
                runningSum += d[tau]
                dPrime[tau] = runningSum > 0 ? d[tau] * Float(tau) / runningSum : 1
            }

            // 3) Absolute threshold: first τ in range dipping below threshold, then
            //    descend to its local minimum.
            var tauEstimate = -1
            var tau = minTau
            while tau < maxTau {
                if dPrime[tau] < threshold {
                    while tau + 1 <= maxTau && dPrime[tau + 1] < dPrime[tau] { tau += 1 }
                    tauEstimate = tau
                    break
                }
                tau += 1
            }

            // Fallback: global minimum of d' in range (report only if reasonably periodic).
            if tauEstimate == -1 {
                var minVal: Float = .greatestFiniteMagnitude
                var minIdx = -1
                for t in minTau...maxTau where dPrime[t] < minVal { minVal = dPrime[t]; minIdx = t }
                guard minIdx > 0, minVal < 0.3 else { return nil }
                tauEstimate = minIdx
            }

            // 4) Parabolic interpolation for sub-sample (sub-cent) precision.
            let refinedTau = parabolicMinimum(dPrime, around: tauEstimate)
            let frequency = sampleRate / refinedTau
            guard frequency >= minFrequency, frequency <= maxFrequency else { return nil }

            let clarity = Double(1 - min(max(dPrime[tauEstimate], 0), 1))
            return Result(frequency: frequency, clarity: clarity)
        }
    }

    /// Quadratic interpolation around index `i` of `a`, returning a fractional index.
    private func parabolicMinimum(_ a: [Float], around i: Int) -> Double {
        guard i > 0, i < a.count - 1 else { return Double(i) }
        let s0 = Double(a[i - 1]), s1 = Double(a[i]), s2 = Double(a[i + 1])
        let denom = s0 + s2 - 2 * s1
        guard denom != 0 else { return Double(i) }
        return Double(i) + 0.5 * (s0 - s2) / denom
    }
}

/// Smooths a stream of noisy per-buffer pitch estimates into a stable readout.
///
/// Two jobs:
///  • A median over a short window rejects single-buffer outliers (a stray octave
///    jump or transient) without the lag of a long average.
///  • A hold/hysteresis keeps reporting the last stable pitch for a short grace
///    period after detection drops, so a ringing-but-decaying note doesn't blink
///    out the instant one buffer fails to detect. Only after `holdFrames`
///    consecutive misses does the readout actually clear.
///
/// Reference type so the audio thread can keep state across buffers.
final class PitchSmoother {
    private var window: [Double] = []
    private var missCount = 0
    private var lastOutput: Double?

    private let capacity: Int
    private let minSamples: Int
    /// Consecutive misses tolerated before the readout clears. At ~11 buffers/sec a
    /// value of 6 is roughly a half-second of grace.
    private let holdFrames: Int

    init(capacity: Int = 5, minSamples: Int = 3, holdFrames: Int = 6) {
        self.capacity = capacity
        self.minSamples = minSamples
        self.holdFrames = holdFrames
    }

    /// Push the latest estimate (nil = no confident pitch this buffer); get the
    /// smoothed value, the held value during the grace period, or nil once cleared.
    func push(_ value: Double?) -> Double? {
        if let value {
            missCount = 0
            window.append(value)
            if window.count > capacity { window.removeFirst() }
            guard window.count >= minSamples else { return lastOutput }
            let sorted = window.sorted()
            lastOutput = sorted[sorted.count / 2]
            return lastOutput
        } else {
            missCount += 1
            if missCount >= holdFrames {
                window.removeAll()
                lastOutput = nil
            }
            return lastOutput   // hold the last reading during the grace period
        }
    }

    func reset() {
        window.removeAll()
        missCount = 0
        lastOutput = nil
    }
}
