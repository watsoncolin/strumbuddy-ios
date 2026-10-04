import Foundation
import Accelerate

/// Finds individual strums in continuous strumming, and guesses each one's direction
/// (wiki: Strumming). The live engine's RMS rising edge can't separate back-to-back
/// strums — energy never dips between them — so this uses **spectral flux**: the
/// increase in log-magnitude spectrum from one short hop to the next, which spikes
/// on every new attack even while earlier strums still ring.
///
/// Direction comes from the attack itself: a down-strum re-plucks the bass strings;
/// an up-strum mostly misses them, so the bass band barely re-attacks.
///
/// Streaming and pure (Accelerate only): feed buffers of any size, get onsets back a
/// few hops late (the direction needs a short look-ahead). Tested off-device on
/// labelled `GuitarSynth` strums in `scripts/main.swift`.
final class StrumOnsetDetector {
    enum Direction: String { case down, up }

    struct Onset: Equatable {
        /// Absolute sample index since the detector started (or was reset).
        let sample: Int
        /// Peak flux, relative to the local threshold (≥ 1).
        let strength: Float
        let direction: Direction
        /// 0…1 — how sure the direction call is.
        let directionConfidence: Float
        /// The raw cues, kept for on-device tuning: the bass share of the new energy…
        let bassShare: Float
        /// Per-bin log-flux of the bass band relative to the treble band (0…1): how
        /// hard the bass strings were *re*-attacked, independent of loudness.
        let bassAttack: Float
    }

    let sampleRate: Double
    let frameSize = 2048           // ~46 ms: enough resolution to split the bass strings
    let hop = 256                  // ~6 ms between frames
    /// No two strums closer than this (fastest 16ths at ~180 bpm are ~83 ms apart).
    var minInterval = 0.07
    /// Flux must beat the recent average by this factor…
    var thresholdRatio: Float = 1.8
    /// …and this absolute floor (quiet noise never counts).
    var floor: Float = 0.6

    private let log2n: vDSP_Length
    private let fft: FFTSetup
    private var window: [Float]
    private let lowBins: Range<Int>
    private let highBins: Range<Int>

    private var pending: [Float] = []        // samples not yet consumed into frames
    private var consumed = 0                 // absolute index of pending[0]
    private var previousLog: [Float]?
    // Per-hop history (index = hop number since start).
    private var flux: [Float] = []
    private var lowFlux: [Float] = []
    private var highFlux: [Float] = []
    private var lowEnergy: [Float] = []
    private var highEnergy: [Float] = []
    private var nextPeakCheck = 0
    private var lastOnsetHop = Int.min / 2

    /// Hops of look-ahead after a peak before it's confirmed and classified.
    private let lookahead = 6

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        log2n = vDSP_Length(log2(Double(frameSize)))
        fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = [Float](repeating: 0, count: frameSize)
        vDSP_hann_window(&window, vDSP_Length(frameSize), Int32(vDSP_HANN_NORM))
        let binHz = sampleRate / Double(frameSize)
        func bin(_ hz: Double) -> Int { Int((hz / binHz).rounded()) }
        // Low = the bass strings' fundamentals (E2–D3 region); high = treble strings
        // and their first partials.
        lowBins = bin(70)..<bin(170)
        highBins = bin(180)..<bin(1_200)
    }

    deinit { vDSP_destroy_fftsetup(fft) }

    func reset() {
        pending = []
        consumed = 0
        previousLog = nil
        flux = []; lowFlux = []; highFlux = []; lowEnergy = []; highEnergy = []
        nextPeakCheck = 0
        lastOnsetHop = Int.min / 2
    }

    /// Feed the next chunk of mono samples; returns any strums now confirmed.
    func process(_ samples: [Float]) -> [Onset] {
        pending += samples
        while pending.count >= frameSize {
            analyzeFrame(Array(pending[0..<frameSize]))
            pending.removeFirst(hop)
            consumed += hop
        }
        return pickPeaks()
    }

    // MARK: Per-frame features

    private func analyzeFrame(_ frame: [Float]) {
        var windowed = [Float](repeating: 0, count: frameSize)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(frameSize))
        let half = frameSize / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var mags = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBufferPointer { wp in
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fft, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(half))
            }
        }
        // Log compression makes flux respond to *relative* change, so a quiet up-strum
        // over a ringing chord still registers.
        let logMag = mags.map { log1pf(100 * $0) }
        var total: Float = 0, low: Float = 0, high: Float = 0
        if let prev = previousLog {
            for k in 1..<half {
                let d = max(0, logMag[k] - prev[k])
                total += d
                if lowBins.contains(k) { low += d } else if highBins.contains(k) { high += d }
            }
        }
        previousLog = logMag
        flux.append(total / Float(half) * 100)
        lowFlux.append(low)
        highFlux.append(high)
        lowEnergy.append(lowBins.reduce(0) { $0 + mags[$1] * mags[$1] })
        highEnergy.append(highBins.reduce(0) { $0 + mags[$1] * mags[$1] })
    }

    // MARK: Peak picking + direction

    private func pickPeaks() -> [Onset] {
        var out: [Onset] = []
        let minHops = max(1, Int(minInterval * sampleRate / Double(hop)))
        let average = Int(0.4 * sampleRate / Double(hop))     // ~0.4 s adaptive baseline
        while nextPeakCheck + lookahead < flux.count {
            let t = nextPeakCheck
            nextPeakCheck += 1
            let f = flux[t]
            let lo = max(0, t - 3), hi = min(flux.count - 1, t + 3)
            guard f == flux[lo...hi].max() else { continue }       // local maximum
            let past = flux[max(0, t - average)..<t]
            let baseline = past.isEmpty ? 0 : past.reduce(0, +) / Float(past.count)
            let threshold = max(floor, baseline * thresholdRatio)
            guard f >= threshold, t - lastOnsetHop >= minHops else { continue }
            lastOnsetHop = t
            let (direction, confidence, bassShare, bassAttack) = classify(at: t)
            // The frame that first "sees" the attack starts a window earlier; centre it.
            let sample = t * hop + frameSize / 2
            out.append(Onset(sample: sample, strength: f / threshold, direction: direction,
                             directionConfidence: confidence, bassShare: bassShare,
                             bassAttack: bassAttack))
        }
        return out
    }

    /// Two cues from the attack, scored + for down:
    ///   • **bass attack** — per-bin log-flux of the bass band vs the treble band:
    ///     a down-strum re-plucks the bass strings; an up-strum leaves them decaying;
    ///   • **bass share** — whether any new bass energy arrived at all (ups ≈ none).
    /// Arrival order (bass-first vs treble-first) was tried and dropped: the 46 ms
    /// frame smears a ~60 ms strum, so it was noise.
    private func classify(at t: Int) -> (Direction, Float, Float, Float) {
        let range = max(0, t - 2)...min(flux.count - 1, t + lookahead)
        let lowPerBin = range.reduce(Float(0)) { $0 + lowFlux[$1] } / Float(lowBins.count)
        let highPerBin = range.reduce(Float(0)) { $0 + highFlux[$1] } / Float(highBins.count)
        let bassAttack = lowPerBin + highPerBin > 0 ? lowPerBin / (lowPerBin + highPerBin) : 0

        let before = max(0, t - 3), after = min(flux.count - 1, t + 3)
        let newLow = max(0, lowEnergy[after] - lowEnergy[before])
        let newHigh = max(0, highEnergy[after] - highEnergy[before])
        let bassShare = newLow + newHigh > 0 ? newLow / (newLow + newHigh) : 0

        let score = (bassAttack - Self.bassAttackSplit) * 10 + (bassShare > Self.bassShareFloor ? 0.5 : -0.5)
        return (score >= 0 ? .down : .up, min(1, abs(score) / 1.5), bassShare, bassAttack)
    }

    /// Tuned on labelled `GuitarSynth` strums (~89% there). Must be re-checked on a
    /// real guitar — the Strumming spike's gate (wiki: Strumming).
    static let bassAttackSplit: Float = 0.42
    static let bassShareFloor: Float = 0.02
}
