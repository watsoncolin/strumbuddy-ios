import Foundation

/// Converts a detected frequency into everything the tuner UI shows: note name,
/// octave, cents offset, and the nearest standard-tuning guitar string. Pure value
/// type so the math is unit-testable (see `scripts/main.swift`).
struct TunerReading: Equatable {
    let frequency: Double
    let noteName: String
    let octave: Int
    /// Signed cents from the nearest equal-tempered note. Negative = flat, positive = sharp.
    let cents: Int
    let nearestString: String?

    var inTune: Bool { abs(cents) <= 5 }

    var directionLabel: String {
        if inTune { return "In tune ✓" }
        return cents < 0 ? "Tune up ↑" : "Tune down ↓"
    }

    private static let noteNames =
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Standard tuning, low to high, as (label, MIDI note).
    private static let standardTuning: [(label: String, midi: Int)] = [
        ("6th (Low E)", 40), ("5th (A)", 45), ("4th (D)", 50),
        ("3rd (G)", 55), ("2nd (B)", 59), ("1st (High E)", 64),
    ]

    /// The six string labels low→high — for a "tune every string" checklist.
    static let stringLabels: [String] = standardTuning.map(\.label)

    init?(frequency: Double?) {
        guard let f = frequency, f > 0 else { return nil }
        self.init(frequency: f)
    }

    init(frequency f: Double) {
        self.frequency = f
        let midi = 69 + 12 * log2(f / 440)
        let rounded = Int(midi.rounded())
        self.cents = Int(((midi - Double(rounded)) * 100).rounded())
        self.noteName = Self.noteNames[((rounded % 12) + 12) % 12]
        self.octave = rounded / 12 - 1

        // Nearest string, only if within ~3 semitones (else you're not near any string).
        let nearest = Self.standardTuning.min { abs(midi - Double($0.midi)) < abs(midi - Double($1.midi)) }
        if let nearest, abs(midi - Double(nearest.midi)) <= 3 {
            self.nearestString = nearest.label
        } else {
            self.nearestString = nil
        }
    }
}
