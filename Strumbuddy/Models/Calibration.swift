import Foundation

/// Persisted audio input latency used to correct strum timestamps for rhythm
/// grading (see wiki: Rhythm Mode). Calibrated by the user via the calibration
/// screen; clamp keeps it sane.
enum Calibration {
    private static let key = "inputLatencySeconds"
    static let defaultLatency: TimeInterval = 0.09

    static func clamp(_ value: TimeInterval) -> TimeInterval { min(max(value, 0), 0.30) }

    static var inputLatency: TimeInterval {
        get { (UserDefaults.standard.object(forKey: key) as? Double) ?? defaultLatency }
        set { UserDefaults.standard.set(clamp(newValue), forKey: key) }
    }
}
