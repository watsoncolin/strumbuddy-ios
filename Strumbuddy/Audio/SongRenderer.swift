import Foundation

/// Renders a whole song as a strummed acoustic guitar — "here's how it should
/// sound" before you play along. One chord per bar (wiki: Songs), a beginner strum
/// pattern, a one-bar click count-in, built from `GuitarSynth` strums. Pure, so the
/// timing and legibility are tested off-device.
struct SongRenderer {
    struct Strum {
        let beat: Double                  // position in the bar, in beats
        let direction: GuitarSynth.Direction
        let gain: Float
    }

    /// The classic beginner pattern: D · D U · U D U (accented downbeat, lighter ups).
    static let beginnerPattern: [Strum] = [
        Strum(beat: 0, direction: .down, gain: 1.0),
        Strum(beat: 1, direction: .down, gain: 0.75),
        Strum(beat: 1.5, direction: .up, gain: 0.5),
        Strum(beat: 2.5, direction: .up, gain: 0.5),
        Strum(beat: 3, direction: .down, gain: 0.75),
        Strum(beat: 3.5, direction: .up, gain: 0.5),
    ]

    var sampleRate: Double = 44_100
    var beatsPerBar = 4
    var pattern = SongRenderer.beginnerPattern
    var countIn = true
    /// How long the final chord rings out.
    var tail = 2.5
    /// The strumming hand stops the strings at each new strum over this long.
    var damping = 0.025

    /// Seconds before bar 0 starts (the count-in bar), for syncing a bar highlight.
    func leadIn(bpm: Int) -> Double {
        countIn ? Double(beatsPerBar) * 60 / Double(bpm) : 0
    }

    func render(_ chords: [Chord], bpm: Int) -> [Float] {
        let beat = 60 / Double(bpm)
        let lead = leadIn(bpm: bpm)
        let total = lead + Double(chords.count * beatsPerBar) * beat + tail
        var out = [Float](repeating: 0, count: Int(total * sampleRate))

        if countIn {
            for b in 0..<beatsPerBar {
                addClick(&out, at: Int(Double(b) * beat * sampleRate), accent: b == 0)
            }
        }

        // A few seeded takes per chord/direction so repeats don't sound copy-pasted.
        var cache: [String: [Float]] = [:]
        func strum(_ chord: Chord, _ dir: GuitarSynth.Direction, take: Int) -> [Float] {
            let key = "\(chord.rawValue)\(dir == .down ? "d" : "u")\(take)"
            if let hit = cache[key] { return hit }
            var synth = GuitarSynth(sampleRate: sampleRate)
            synth.seed = UInt64(truncatingIfNeeded: key.hashValueStable)
            let audio = synth.strum(chord, direction: dir, duration: tail + 0.1)
            cache[key] = audio
            return audio
        }

        // Each strum rings until the next one starts, then is damped quickly.
        var onsets: [(start: Int, audio: [Float], gain: Float)] = []
        for (bar, chord) in chords.enumerated() {
            for (i, s) in pattern.enumerated() {
                let t = lead + (Double(bar * beatsPerBar) + s.beat) * beat
                onsets.append((Int(t * sampleRate), strum(chord, s.direction, take: (bar + i) % 3), s.gain))
            }
        }
        let fade = max(1, Int(damping * sampleRate))
        for (n, o) in onsets.enumerated() {
            let next = n + 1 < onsets.count ? onsets[n + 1].start : Int.max
            for i in 0..<o.audio.count {
                let idx = o.start + i
                guard idx < out.count else { break }
                var g = o.gain
                if idx >= next {
                    let k = idx - next
                    if k >= fade { break }
                    g *= 1 - Float(k) / Float(fade)
                }
                out[idx] += o.audio[i] * g
            }
        }

        // Normalize, leaving a little headroom.
        let peak = out.map(abs).max() ?? 0
        if peak > 0 {
            let scale = 0.89 / peak
            for i in 0..<out.count { out[i] *= scale }
        }
        return out
    }

    /// A short woodblock-ish click, higher on the accent — same feel as the metronome.
    private func addClick(_ out: inout [Float], at start: Int, accent: Bool) {
        let f: Float = accent ? 1_500 : 1_000
        let n = Int(0.03 * sampleRate)
        for i in 0..<n where start + i < out.count {
            let t = Float(i) / Float(sampleRate)
            out[start + i] += sinf(2 * .pi * f * t) * expf(-t * 80) * 0.5
        }
    }
}

private extension String {
    /// Stable across launches (`hashValue` is randomly seeded per process).
    var hashValueStable: UInt64 {
        utf8.reduce(1_469_598_103_934_665_603) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }   // FNV-1a
    }
}
