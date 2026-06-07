import Foundation
import Accelerate

/// Renders a recognized chord timeline to synth-guitar audio, so the analysis can be
/// played back and judged by ear (BYO-song). Efficient: one strum waveform is
/// rendered per unique chord, then overlap-added (vDSP) at each onset — fast even for
/// long songs. Pure (Accelerate only).
struct ChordSynth {
    var strumInterval = 0.55     // seconds between re-strums within a held chord
    var strumSpread = 0.016      // delay between strings in one strum
    var harmonics = 5

    /// Render the whole timeline to mono samples at `sampleRate`.
    func render(_ timeline: [TimedChord], sampleRate: Double) -> [Float] {
        guard let total = timeline.map(\.end).max(), total > 0 else { return [] }
        var out = [Float](repeating: 0, count: Int(total * sampleRate) + 1)
        var cache: [ChordSymbol: [Float]] = [:]

        for tc in timeline {
            let strum: [Float]
            if let cached = cache[tc.symbol] {
                strum = cached
            } else {
                strum = renderStrum(tc.symbol, sampleRate: sampleRate)
                cache[tc.symbol] = strum
            }
            var onset = tc.start
            while onset < tc.end {
                let startIdx = Int(onset * sampleRate)
                let maxLen = min(strum.count, Int(tc.end * sampleRate) - startIdx, out.count - startIdx)
                if maxLen > 0 {
                    out.withUnsafeMutableBufferPointer { o in
                        strum.withUnsafeBufferPointer { s in
                            vDSP_vadd(o.baseAddress! + startIdx, 1, s.baseAddress!, 1,
                                      o.baseAddress! + startIdx, 1, vDSP_Length(maxLen))
                        }
                    }
                }
                onset += strumInterval
            }
        }
        normalize(&out)
        return out
    }

    /// One down-strum of the chord: a low root + the triad, notes staggered, each a
    /// few decaying harmonics.
    private func renderStrum(_ symbol: ChordSymbol, sampleRate: Double) -> [Float] {
        let midis = [36 + symbol.root] + symbol.pitchClasses.map { 48 + $0 }   // bass + triad
        let freqs = midis.map { 440 * pow(2.0, (Double($0) - 69) / 12) }
        let length = Int((strumSpread * Double(freqs.count) + strumInterval * 1.6) * sampleRate)
        var buf = [Float](repeating: 0, count: max(1, length))

        for (i, f) in freqs.enumerated() {
            let startIdx = Int(Double(i) * strumSpread * sampleRate)
            let noteLen = Int(strumInterval * 1.6 * sampleRate)
            for j in 0..<noteLen {
                let idx = startIdx + j
                if idx >= buf.count { break }
                let t = Double(j) / sampleRate
                let env = exp(-t * 3.0)
                var s = 0.0
                for k in 1...harmonics { s += (1.0 / Double(k)) * sin(2 * .pi * Double(k) * f * t) }
                buf[idx] += Float(s * env * 0.12)
            }
        }
        return buf
    }

    private func normalize(_ buf: inout [Float]) {
        var maxVal: Float = 0
        vDSP_maxmgv(buf, 1, &maxVal, vDSP_Length(buf.count))
        if maxVal > 0 { var scale = 0.9 / maxVal; vDSP_vsmul(buf, 1, &scale, &buf, 1, vDSP_Length(buf.count)) }
    }
}
