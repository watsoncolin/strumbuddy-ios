import Foundation

/// Physically-modelled acoustic guitar — renders a real six-string strum of a chord
/// shape so the app can play "what this chord should sound like." Pure (Foundation
/// only) so it renders and is tested off-device via `scripts/main.swift`.
///
/// Each string is an extended Karplus-Strong loop (Jaffe & Smith 1983):
///   • excitation: a one-period noise burst, low-passed by pick hardness and
///     comb-filtered at the pick position (the "plucked near the soundhole" timbre);
///   • loop: integer delay + two-point averaging loss filter (highs die first, like a
///     real string) + first-order allpass for exact fractional tuning;
///   • per-string T60 so bass strings ring longer than trebles.
/// The strings are staggered into a strum, then run through a few resonators that
/// stand in for the guitar body's main air/top-plate modes.
struct GuitarSynth {
    enum Direction { case down, up }

    var sampleRate: Double = 44_100
    /// Seconds between adjacent strings in a strum.
    var strumSpread = 0.013
    /// Pick position as a fraction of string length from the bridge.
    var pickPosition = 0.12
    /// 0…1 — how hard/bright the pick attack is.
    var brightness = 0.55
    /// How much of the body-resonance signal is mixed in.
    var bodyMix = 0.45
    /// High-pass corner (Hz) for the output voicing.
    var highPass = 110.0
    /// Seeds the noise and humanization so renders are reproducible.
    var seed: UInt64 = 0x5EED

    /// Standard-tuning open-string frequencies, low E → high E.
    static let openStrings: [Double] = [82.41, 110.0, 146.83, 196.0, 246.94, 329.63]

    /// Strum a chord from the diagram library.
    func strum(_ chord: Chord, direction: Direction = .down, duration: Double = 2.6) -> [Float] {
        strum(frets: (ChordShape.library[chord] ?? .unknown).frets,
              direction: direction, duration: duration)
    }

    /// Strum an arbitrary shape (fret per string, -1 = muted, low E first).
    func strum(frets: [Int], direction: Direction = .down, duration: Double = 2.6) -> [Float] {
        var rng = SplitMix64(seed: seed)
        let count = Int(duration * sampleRate)
        var mix = [Double](repeating: 0, count: count)
        let order = direction == .down ? Array(0..<6) : Array((0..<6).reversed())

        var onset = 0.0
        for (position, string) in order.enumerated() {
            let fret = frets[string]
            // Humanize: a little timing jitter and velocity variation per string; a
            // down-strum digs into the bass, an up-strum catches the trebles lighter.
            let jitter = rng.uniform(-0.002, 0.002)
            let start = Int(max(0, onset + jitter) * sampleRate)
            let accent = direction == .down ? 1.0 - 0.06 * Double(position) : 0.75
            let velocity = accent * rng.uniform(0.88, 1.0)

            let note: [Double]
            if fret < 0 {
                // A muted string still gets hit — a short, dead thud.
                note = pluck(frequency: Self.openStrings[string], velocity: velocity * 0.25,
                             t60: 0.05, samples: count - start, rng: &rng)
            } else {
                let cents = rng.uniform(-1.5, 1.5)   // tiny detune — real strings never agree exactly
                let f = Self.openStrings[string] * pow(2, (Double(fret) + cents / 100) / 12)
                note = pluck(frequency: f, velocity: velocity, t60: decayTime(f),
                             samples: count - start, rng: &rng)
            }
            for i in 0..<note.count { mix[start + i] += note[i] }
            onset += strumSpread * rng.uniform(0.85, 1.15)
        }

        applyBody(&mix)
        return finish(mix)
    }

    /// A single plucked note (e.g. one string), for previews and tests.
    func pluck(frequency: Double, velocity: Double = 0.9, duration: Double = 2.0) -> [Float] {
        var rng = SplitMix64(seed: seed)
        var buf = pluck(frequency: frequency, velocity: velocity, t60: decayTime(frequency),
                        samples: Int(duration * sampleRate), rng: &rng)
        applyBody(&buf)
        return finish(buf)
    }

    // MARK: - String model

    /// Bass strings sustain ~5 s, the high e ~2.5 s.
    private func decayTime(_ f: Double) -> Double {
        5.5 * pow(Self.openStrings[0] / f, 0.55)
    }

    private func pluck(frequency f: Double, velocity: Double, t60: Double,
                       samples count: Int, rng: inout SplitMix64) -> [Double] {
        guard count > 0 else { return [] }
        var out = [Double](repeating: 0, count: count)

        // Loop delay = L (line) + 0.5 (averager) + d (allpass) = one period.
        let period = sampleRate / f
        let lineLength = max(2, Int(period - 0.6))
        let d = period - 0.5 - Double(lineLength)       // in ~[0.1, 1.1)
        let apC = (1 - d) / (1 + d)
        let rho = pow(0.001, 1 / (f * t60))             // per-period gain for the T60

        // Excitation: the string's displacement at release — a triangle peaking at
        // the pick point, whose harmonics fall ~1/n² with nulls at multiples of
        // 1/pickPosition (white noise here sounds harpsichord-bright). A touch of
        // noise adds pick texture; a one-pole low-pass sets pick hardness. DC removed
        // so the loop doesn't accumulate an offset.
        let exLength = max(2, Int(period.rounded()))
        let peak = max(1, pickPosition * Double(exLength))
        let lpA = 0.25 + 0.6 * brightness * velocity
        var combed = [Double](repeating: 0, count: exLength)
        var lp = 0.0
        for i in 0..<exLength {
            let x = Double(i)
            let tri = x < peak ? x / peak : (Double(exLength) - x) / (Double(exLength) - peak)
            lp += lpA * (tri + 0.08 * rng.uniform(-1, 1) - lp)
            combed[i] = lp
        }
        let mean = combed.reduce(0, +) / Double(exLength)
        for i in 0..<exLength { combed[i] = (combed[i] - mean) * velocity }

        var line = [Double](repeating: 0, count: lineLength)
        var idx = 0
        var prev = 0.0, apX1 = 0.0, apY1 = 0.0, lastOut = 0.0
        for n in 0..<count {
            let y = line[idx]
            let loss = rho * 0.5 * (y + prev)
            prev = y
            let ap = apC * loss + apX1 - apC * apY1
            apX1 = loss; apY1 = ap
            line[idx] = ap + (n < exLength ? combed[n] : 0)
            idx += 1; if idx == lineLength { idx = 0 }
            // Bridge pickup: the body is driven by the string's *slope* at the bridge,
            // i.e. the derivative of displacement — tilts the 1/n² pluck to the ~1/n
            // spectrum a real acoustic radiates.
            out[n] = y - lastOut
            lastOut = y
        }
        return out
    }

    // MARK: - Body + output

    /// Parallel resonators at typical dreadnought body modes (Helmholtz air mode,
    /// first top-plate modes) plus a broad presence bump, blended with the dry strings.
    private func applyBody(_ buf: inout [Double]) {
        let modes: [(f: Double, q: Double, gain: Double)] = [
            (100, 2.5, 0.4), (205, 3, 0.8), (390, 2.5, 0.6), (2_800, 0.9, 0.3),
        ]
        var wet = [Double](repeating: 0, count: buf.count)
        for m in modes {
            var bp = Biquad.bandpass(f: m.f, q: m.q, sampleRate: sampleRate)
            for i in 0..<buf.count { wet[i] += m.gain * bp.process(buf[i]) }
        }
        // Voice for a phone speaker: roll off the boomy low end it can't reproduce
        // (and that smears the low strings together), and tame the top past ~6 kHz.
        var lows = Biquad.highpass(f: highPass, q: 0.7, sampleRate: sampleRate)
        var air = Biquad.lowpass(f: 6_500, q: 0.7, sampleRate: sampleRate)
        for i in 0..<buf.count { buf[i] = air.process(lows.process(buf[i] + bodyMix * wet[i])) }
    }

    /// DC-block, fade the tail to avoid a click, normalize to -1 dBFS-ish.
    private func finish(_ buf: [Double]) -> [Float] {
        var out = [Float](repeating: 0, count: buf.count)
        var x1 = 0.0, y1 = 0.0
        for i in 0..<buf.count {
            let y = buf[i] - x1 + 0.995 * y1
            x1 = buf[i]; y1 = y
            out[i] = Float(y)
        }
        let fade = min(out.count, Int(0.25 * sampleRate))
        for i in 0..<fade {
            out[out.count - fade + i] *= Float(1 - Double(i) / Double(fade))
        }
        let peak = out.map(abs).max() ?? 0
        if peak > 0 {
            let scale = 0.89 / peak
            for i in 0..<out.count { out[i] *= scale }
        }
        return out
    }
}

/// RBJ-cookbook biquad (direct form I).
private struct Biquad {
    let b0, b1, b2, a1, a2: Double
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }

    /// Constant 0 dB peak-gain bandpass.
    static func bandpass(f: Double, q: Double, sampleRate: Double) -> Biquad {
        let w = 2 * .pi * f / sampleRate, alpha = sin(w) / (2 * q), a0 = 1 + alpha
        return Biquad(b0: alpha / a0, b1: 0, b2: -alpha / a0,
                      a1: -2 * cos(w) / a0, a2: (1 - alpha) / a0)
    }

    static func highpass(f: Double, q: Double, sampleRate: Double) -> Biquad {
        let w = 2 * .pi * f / sampleRate, alpha = sin(w) / (2 * q), c = cos(w), a0 = 1 + alpha
        return Biquad(b0: (1 + c) / 2 / a0, b1: -(1 + c) / a0, b2: (1 + c) / 2 / a0,
                      a1: -2 * c / a0, a2: (1 - alpha) / a0)
    }

    static func lowpass(f: Double, q: Double, sampleRate: Double) -> Biquad {
        let w = 2 * .pi * f / sampleRate, alpha = sin(w) / (2 * q), c = cos(w), a0 = 1 + alpha
        return Biquad(b0: (1 - c) / 2 / a0, b1: (1 - c) / a0, b2: (1 - c) / 2 / a0,
                      a1: -2 * c / a0, a2: (1 - alpha) / a0)
    }
}

/// Small deterministic PRNG so renders (and tests) are reproducible.
private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func uniform(_ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * Double(next() >> 11) / Double(1 << 53)
    }
}
