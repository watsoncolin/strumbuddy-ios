import Foundation
import Accelerate

/// A timed chord in a recognized progression.
struct TimedChord: Equatable {
    let symbol: ChordSymbol
    let start: Double   // seconds
    let end: Double
}

/// Offline chord recognition spike for [[BYO-Song (v2)]]: window the audio into
/// chroma frames, cosine-match each against the 24 maj/min templates, then smooth
/// the frame estimates with a self-transition-biased Viterbi and run-length encode
/// into a chord timeline. Pure (Accelerate only), so it's measurable in the harness.
///
/// NOTE: this validates the *algorithm* on clean input. Real-mix accuracy (drums,
/// vocals, bass) is the open question and needs real recordings on a device.
struct ChordRecognizer {
    var fftSize = 4096
    var hop = 2048
    /// Reward for staying on the same chord between frames (favours stable chords).
    var selfTransitionBonus = 0.25

    private let chromagram = Chromagram(fftSize: 4096)
    private let templates: [(symbol: ChordSymbol, vector: [Float])]

    init() {
        var t: [(ChordSymbol, [Float])] = []
        for root in 0..<12 {
            for quality in [ChordSymbol.Quality.major, .minor] {
                let symbol = ChordSymbol(root: root, quality: quality)
                var vector = [Float](repeating: 0, count: 12)
                for pc in symbol.pitchClasses { vector[pc] = 1 }
                t.append((symbol, vector))
            }
        }
        templates = t
    }

    func recognize(_ samples: [Float], sampleRate: Float) -> [TimedChord] {
        let frames = chromaFrames(samples, sampleRate: sampleRate)
        guard !frames.isEmpty else { return [] }
        let n = frames.count
        let m = templates.count

        // Emission scores: cosine of each frame's chroma against each template.
        var emission = [[Double]](repeating: [Double](repeating: 0, count: m), count: n)
        for t in 0..<n {
            for s in 0..<m { emission[t][s] = cosine(frames[t].chroma, templates[s].vector) }
        }

        // Viterbi with a uniform switch cost + a self-stay bonus (O(n·m)).
        var dp = emission[0]
        var back = [[Int]](repeating: [Int](repeating: 0, count: m), count: n)
        for t in 1..<n {
            var bestPrev = 0
            for s in 1..<m where dp[s] > dp[bestPrev] { bestPrev = s }
            var cur = [Double](repeating: 0, count: m)
            for s in 0..<m {
                let stay = dp[s] + selfTransitionBonus
                if stay >= dp[bestPrev] {
                    cur[s] = emission[t][s] + stay; back[t][s] = s
                } else {
                    cur[s] = emission[t][s] + dp[bestPrev]; back[t][s] = bestPrev
                }
            }
            dp = cur
        }

        // Backtrack the best path.
        var path = [Int](repeating: 0, count: n)
        var last = 0
        for s in 1..<m where dp[s] > dp[last] { last = s }
        path[n - 1] = last
        if n >= 2 { for t in stride(from: n - 1, to: 0, by: -1) { path[t - 1] = back[t][path[t]] } }

        // Run-length encode into a timeline.
        var result: [TimedChord] = []
        var i = 0
        while i < n {
            var j = i
            while j + 1 < n && path[j + 1] == path[i] { j += 1 }
            let end = j + 1 < n ? frames[j + 1].time
                                : frames[j].time + Double(hop) / Double(sampleRate)
            result.append(TimedChord(symbol: templates[path[i]].symbol, start: frames[i].time, end: end))
            i = j + 1
        }
        return result
    }

    /// The recognized chord covering a given time, if any.
    func chord(at time: Double, in timeline: [TimedChord]) -> ChordSymbol? {
        timeline.first { time >= $0.start && time < $0.end }?.symbol
    }

    // MARK: - Internals

    private func chromaFrames(_ samples: [Float], sampleRate: Float) -> [(time: Double, chroma: [Float])] {
        var frames: [(Double, [Float])] = []
        var start = 0
        while start + fftSize <= samples.count {
            let frame = Array(samples[start..<start + fftSize])
            let chroma = chromagram.compute(frame, sampleRate: sampleRate).chroma
            frames.append((Double(start) / Double(sampleRate), chroma))
            start += hop
        }
        return frames
    }

    private func cosine(_ a: [Float], _ b: [Float]) -> Double {
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, 12)
        vDSP_svesq(a, 1, &na, 12)
        vDSP_svesq(b, 1, &nb, 12)
        let denom = sqrt(Double(na)) * sqrt(Double(nb))
        return denom > 0 ? Double(dot) / denom : 0
    }
}
