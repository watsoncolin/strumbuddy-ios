import Foundation

/// Pure beat-grid math for the metronome and (later) timing grading. No audio, so
/// it's unit-testable off-device. `elapsed` is seconds since the metronome started.
struct BeatClock {
    let bpm: Double
    var beatInterval: Double { 60.0 / max(bpm, 1) }

    /// Which beat (0-based) a given elapsed time falls on.
    func beatIndex(elapsed: Double) -> Int {
        max(0, Int(elapsed / beatInterval))
    }

    /// 0…1 alignment of an onset to the nearest beat — 1.0 = dead on the beat,
    /// 0 = a full half-beat off. This is the timing axis for rhythm grading.
    func alignment(elapsed: Double) -> Double {
        guard elapsed >= 0, beatInterval > 0 else { return 0 }
        let phase = elapsed.truncatingRemainder(dividingBy: beatInterval)
        let distance = min(phase, beatInterval - phase) / (beatInterval / 2)
        return max(0, 1 - distance)
    }
}
