import Foundation

// Demo-seed for App Store screenshots: writes a realistic ~12-day practice history
// to observations.json (matching ObservationLog's default JSON encoding) and prints
// the streak day-ordinals to set as `completedSessionDays`. Builds the data with the
// app's real model types so the format always matches the decoder.
//
//   swiftc -O Strumbuddy/Models/Chord.swift Strumbuddy/Models/Skill.swift \
//          Strumbuddy/Models/ScoreAxes.swift Strumbuddy/Models/Observation.swift \
//          scripts/seed_observations.swift -o /tmp/seed && /tmp/seed /tmp/observations.json

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/observations.json"
let cal = Calendar.current
let now = Date()
let days = 12   // consecutive practice days → 12-day streak

func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
    let base = cal.date(byAdding: .day, value: -daysAgo, to: now)!
    return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
}

func clamp(_ v: Double) -> Double { min(0.98, max(0.0, v)) }

var obs: [Observation] = []

func chordReps(_ c: Chord, base: Double, daysAgo: Int, reps: Int) {
    let progress = Double(days - daysAgo) / Double(days)      // 0…1 over the run
    for r in 0..<reps {
        let s = clamp(base + 0.16 * progress + 0.02 * Double(r))
        let ax = ScoreAxes(accuracy: clamp(s + 0.03), cleanliness: s, timing: clamp(s - 0.05))
        obs.append(Observation(timestamp: date(daysAgo: daysAgo, hour: 18, minute: 5 + r * 2),
                               implicatedSkills: [.chord(c)],
                               context: .init(isolation: .isolated, bpm: nil, source: .practice),
                               scores: ax))
    }
}

func transitionReps(_ a: Chord, _ b: Chord, base: Double, daysAgo: Int, reps: Int) {
    let progress = Double(days - daysAgo) / Double(days)
    for r in 0..<reps {
        let s = clamp(base + 0.16 * progress + 0.02 * Double(r))
        let ax = ScoreAxes(accuracy: clamp(s + 0.02), cleanliness: clamp(s - 0.02), timing: clamp(s - 0.04))
        obs.append(Observation(timestamp: date(daysAgo: daysAgo, hour: 18, minute: 30 + r * 2),
                               implicatedSkills: [.transition(from: a, to: b), .chord(a), .chord(b)],
                               context: .init(isolation: .inSequence, bpm: 60, source: .practice),
                               scores: ax))
    }
}

for d in stride(from: days - 1, through: 0, by: -1) {
    // Mastered core
    chordReps(.em, base: 0.80, daysAgo: d, reps: 2)
    chordReps(.c,  base: 0.78, daysAgo: d, reps: 2)
    chordReps(.g,  base: 0.75, daysAgo: d, reps: 2)
    // Learning
    chordReps(.d,  base: 0.62, daysAgo: d, reps: 2)
    chordReps(.a,  base: 0.55, daysAgo: d, reps: 1)
    // Transitions: two solid, one clear focus (weak-but-ready)
    transitionReps(.em, .c, base: 0.72, daysAgo: d, reps: 2)
    transitionReps(.c,  .g, base: 0.70, daysAgo: d, reps: 2)
    transitionReps(.g,  .d, base: 0.50, daysAgo: d, reps: 2)   // the focus
}

let data = try JSONEncoder().encode(obs)
try data.write(to: URL(fileURLWithPath: outPath))

// Streak ordinals (era day numbers) for the last `days` consecutive days incl. today.
let today = cal.ordinality(of: .day, in: .era, for: now) ?? 0
let ordinals = (0..<days).map { String(today - $0) }.reversed().joined(separator: " ")

FileHandle.standardError.write("Wrote \(obs.count) observations → \(outPath)\n".data(using: .utf8)!)
print("ORDINALS: \(ordinals)")
