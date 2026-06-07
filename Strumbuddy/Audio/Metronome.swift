import Foundation
import AVFoundation
import Combine

/// Metronome + beat grid (design-doc §4 / §6 table stakes). Also the source of the
/// timing reference the scoring engine grades note onsets against.
@MainActor
final class Metronome: ObservableObject {
    @Published var bpm: Int = 60
    @Published private(set) var isRunning = false
    /// Monotonic beat index since start; views can pulse on change.
    @Published private(set) var beat: Int = 0

    private var timer: Timer?

    func start() {
        stop()
        isRunning = true
        beat = 0
        let interval = 60.0 / Double(bpm)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.beat += 1
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func tick() {
        // TODO(audio): play a click sample; for now this is the timing source only.
    }

    /// Onset alignment 0…1 for a note played at `onset` relative to the grid —
    /// feeds the `timing` scoring axis.
    func timingScore(forOnset onset: Date, start: Date) -> Double {
        let beatLen = 60.0 / Double(bpm)
        let elapsed = onset.timeIntervalSince(start)
        let phase = elapsed.truncatingRemainder(dividingBy: beatLen)
        let distance = min(phase, beatLen - phase) / (beatLen / 2)
        return max(0, 1 - distance)
    }
}
