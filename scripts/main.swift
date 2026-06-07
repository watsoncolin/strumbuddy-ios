// Off-device test harness for the tuner's pure math.
//
// Compile together with the pure sources and run on macOS — no simulator needed:
//
//   swiftc Strumbuddy/Audio/PitchDetector.swift \
//          Strumbuddy/Features/Shared/TunerReading.swift \
//          scripts/main.swift -o /tmp/tunercheck && /tmp/tunercheck
//
// Verifies PitchDetector (YIN) against synthesized guitar-like tones and the
// TunerReading note/cents/string math. Exits non-zero on any failure.

import Foundation

// MARK: - Test helpers

let sampleRate = 44_100.0
let frameCount = 4096
var failures = 0

func centsError(detected: Double, expected: Double) -> Double {
    1200 * log2(detected / expected)
}

/// A guitar-ish tone: fundamental plus decaying harmonics (tests octave robustness).
func tone(_ freq: Double, harmonics: Int = 6, amplitude: Double = 0.25) -> [Float] {
    (0..<frameCount).map { n in
        let t = Double(n) / sampleRate
        var s = 0.0
        for k in 1...harmonics { s += (1.0 / Double(k)) * sin(2 * .pi * Double(k) * freq * t) }
        return Float(s * amplitude)
    }
}

func check(_ label: String, _ condition: Bool, _ detail: String = "") {
    let mark = condition ? "✅" : "❌"
    print("\(mark) \(label)\(detail.isEmpty ? "" : "  — \(detail)")")
    if !condition { failures += 1 }
}

// MARK: - PitchDetector: the six open strings + extras

print("== PitchDetector (YIN) ==")
let detector = PitchDetector(sampleRate: sampleRate)
let tolerance = 6.0  // cents — synthesized tones should be tight

let strings: [(String, Double)] = [
    ("Low E (E2)", 82.41), ("A (A2)", 110.00), ("D (D3)", 146.83),
    ("G (G3)", 196.00), ("B (B3)", 246.94), ("High E (E4)", 329.63),
    ("A (A4)", 440.00),
]
for (name, freq) in strings {
    if let r = detector.detect(tone(freq)) {
        let err = centsError(detected: r.frequency, expected: freq)
        check("\(name)", abs(err) <= tolerance,
              String(format: "got %.2f Hz (%+.2f¢), clarity %.2f", r.frequency, err, r.clarity))
    } else {
        check("\(name)", false, "no pitch detected")
    }
}

// Detuned strings should report the detune accurately.
let detunedFreq = 440.0 * pow(2.0, 20.0 / 1200.0)  // +20 cents
if let r = detector.detect(tone(detunedFreq)) {
    let err = centsError(detected: r.frequency, expected: detunedFreq)
    check("A4 +20¢ detune", abs(err) <= tolerance,
          String(format: "got %.2f Hz (%+.2f¢)", r.frequency, err))
} else {
    check("A4 +20¢ detune", false, "no pitch detected")
}

// Silence must produce no pitch.
check("Silence → nil", detector.detect([Float](repeating: 0, count: frameCount)) == nil)

// MARK: - TunerReading: note / cents / string mapping

print("\n== TunerReading ==")

let a4 = TunerReading(frequency: 440.0)
check("440 Hz → A", a4.noteName == "A", "got \(a4.noteName)")
check("440 Hz → octave 4", a4.octave == 4, "got \(a4.octave)")
check("440 Hz → 0¢", abs(a4.cents) <= 1, "got \(a4.cents)¢")

let lowE = TunerReading(frequency: 82.41)
check("82.41 Hz → E2", lowE.noteName == "E" && lowE.octave == 2, "got \(lowE.noteName)\(lowE.octave)")
check("82.41 Hz → 6th string", lowE.nearestString == "6th (Low E)", "got \(lowE.nearestString ?? "nil")")

let highE = TunerReading(frequency: 329.63)
check("329.63 Hz → 1st string", highE.nearestString == "1st (High E)", "got \(highE.nearestString ?? "nil")")

let flatA = TunerReading(frequency: 440.0 * pow(2.0, -12.0 / 1200.0))  // -12 cents
check("A4 -12¢ → flat reading", flatA.noteName == "A" && flatA.cents < -5 && !flatA.inTune,
      "got \(flatA.noteName) \(flatA.cents)¢")
check("A4 -12¢ → 'Tune up'", flatA.directionLabel.contains("Tune up"), "got \(flatA.directionLabel)")

// MARK: - Summary

print("\n\(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")")
exit(failures == 0 ? 0 : 1)
