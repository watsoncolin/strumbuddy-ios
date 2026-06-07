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

// MARK: - PitchSmoother: median + hold/hysteresis

print("\n== PitchSmoother ==")
do {
    let sm = PitchSmoother(capacity: 5, minSamples: 3, holdFrames: 3)
    check("warms up (1st frame nil)", sm.push(100) == nil)
    check("warms up (2nd frame nil)", sm.push(100) == nil)
    check("emits after minSamples", sm.push(100) == 100)
    check("rejects single outlier (median)", sm.push(200) == 100)
    // Hold: misses within grace keep the last reading, then it clears.
    check("hold miss 1 keeps reading", sm.push(nil) == 100)
    check("hold miss 2 keeps reading", sm.push(nil) == 100)
    check("clears after holdFrames", sm.push(nil) == nil)
}

// MARK: - Chromagram + ChordDetector (identity + cleanliness)

print("\n== Chromagram + ChordDetector ==")

func midiFreq(_ midi: Int) -> Double { 440 * pow(2.0, (Double(midi) - 69) / 12) }

/// Synthesize a chord as a harmonic-rich triad in octave 3 (pitch class p → C3+p),
/// optionally with extra out-of-chord pitch classes, or extra absolute MIDI notes
/// (e.g. a low E string at MIDI 40). Mimics the harmonic leakage a real guitar
/// produces, so the detector is tested against a realistic chromagram.
func chordTone(_ pitchClasses: [Int], extra: [Int] = [], extraMidi: [Int] = [],
               harmonics: Int = 5, amplitude: Double = 0.2) -> [Float] {
    let notes = (pitchClasses + extra).map { 48 + $0 } + extraMidi
    return (0..<frameCount).map { n in
        let t = Double(n) / sampleRate
        var s = 0.0
        for midi in notes {
            let f = midiFreq(midi)
            for k in 1...harmonics { s += (1.0 / Double(k)) * sin(2 * .pi * Double(k) * f * t) }
        }
        return Float(s * amplitude / Double(notes.count))
    }
}

let chromagram = Chromagram(fftSize: 4096)
let chordDetector = ChordDetector()
func spec(of pcs: [Int], extra: [Int] = [], extraMidi: [Int] = []) -> Chromagram.Spectrum {
    chromagram.compute(chordTone(pcs, extra: extra, extraMidi: extraMidi), sampleRate: Float(sampleRate))
}
func chroma(of pcs: [Int], extra: [Int] = []) -> [Float] { spec(of: pcs, extra: extra).chroma }

// Identity: each chord's full triad should be recognized as itself.
for chord in Chord.allCases {
    let pcs = chord.expectedPitchClasses.map { $0.rawValue }
    let r = chordDetector.detect(chroma(of: pcs))
    check("identify \(chord.displayName)", r?.chord == chord,
          "got \(r?.chord.displayName ?? "nil"), conf \(String(format: "%.2f", r?.confidence ?? 0))")
}

// Clean chord → high cleanliness, every expected note clean.
do {
    let r = chordDetector.score(.c, chroma(of: [0, 4, 7]))
    check("clean C: high cleanliness", r.cleanliness >= 0.8, String(format: "%.2f", r.cleanliness))
    check("clean C: all expected clean",
          Chord.c.expectedPitchClasses.allSatisfy { r.stringQuality[$0] == .clean })
}

// Missing note (play C and G, omit E) → E flagged muted, cleanliness drops.
do {
    let r = chordDetector.score(.c, chroma(of: [0, 7]))   // C, G only
    check("C missing E: E muted", r.stringQuality[.e] == .muted,
          "got \(r.stringQuality[.e].map(String.init(describing:)) ?? "nil")")
    check("C missing E: cleanliness drops", r.cleanliness < 0.8, String(format: "%.2f", r.cleanliness))
}

// Wrong note (C triad + an out-of-chord F#) → F# flagged buzzing.
do {
    let r = chordDetector.score(.c, chroma(of: [0, 4, 7], extra: [6]))  // + F#
    check("C + F#: F# buzzing", r.stringQuality[.fSharp] == .buzzing,
          "got \(r.stringQuality[.fSharp].map(String.init(describing:)) ?? "nil")")
}

// Muted-string detection: a ringing low-E string on a C chord. E is a chord tone,
// so the pitch-class path can't catch it — but the fundamental-frequency check can.
do {
    let s = spec(of: [0, 4, 7], extraMidi: [40])   // C triad + ringing low E string (E2 ~82 Hz)
    let r = chordDetector.score(.c, s.chroma, spectrum: s)
    check("C + ringing low E: 6th string flagged", r.ringingMutedStrings.contains(0),
          "got \(r.ringingMutedStrings)")
    check("C + ringing low E: cleanliness penalized", r.cleanliness < 0.8,
          String(format: "%.2f", r.cleanliness))
}
do {
    let s = spec(of: [0, 4, 7])                      // proper C, low E not played
    let r = chordDetector.score(.c, s.chroma, spectrum: s)
    check("clean C: no muted strings flagged", r.ringingMutedStrings.isEmpty,
          "got \(r.ringingMutedStrings)")
}

// ChordScoreSmoother (peak-hold): keeps the best strum, holds through quiet, clears.
do {
    let sm = ChordScoreSmoother(holdFrames: 3)
    let clean = chordDetector.score(.c, chroma(of: [0, 4, 7]))        // high quality
    let poor  = chordDetector.score(.c, chroma(of: [0]))             // only root → low quality
    check("smoother emits when energetic", sm.push(clean, energetic: true).current != nil)
    check("peak-hold keeps best over a worse later frame",
          sm.push(poor, energetic: true).current?.cleanliness == clean.cleanliness)
    check("smoother holds on quiet 1", sm.push(nil, energetic: false).current != nil)
    check("smoother holds on quiet 2", sm.push(nil, energetic: false).current != nil)
    let finalUpdate = sm.push(nil, energetic: false)   // holdFrames=3 → clears here
    check("smoother clears after holdFrames", finalUpdate.current == nil)
    check("finalizes the best attempt on clear", finalUpdate.finalized?.cleanliness == clean.cleanliness)
}

// MARK: - ChordShape fingerings (data correctness)

print("\n== ChordShape fingerings ==")
for chord in Chord.allCases {
    guard let shape = ChordShape.library[chord] else { check("shape \(chord.displayName)", false); continue }
    var sounded = Set<Int>()
    for i in 0..<6 { if let pc = shape.soundingPitchClass(forString: i) { sounded.insert(pc) } }
    let expected = Set(chord.expectedPitchClasses.map { $0.rawValue })
    check("\(chord.displayName) shape sounds all its notes", expected.isSubset(of: sounded),
          "expected \(expected.sorted()), sounds \(sounded.sorted())")
}
// Spot-check the string→note mapping used by the muted-note feedback.
do {
    let g = ChordShape.library[.g]!
    check("G: open D string sounds D", g.soundingPitchClass(forString: 2) == PitchClass.d.rawValue)
    let c = ChordShape.library[.c]!
    check("C: D string at 2nd fret sounds E", c.soundingPitchClass(forString: 2) == PitchClass.e.rawValue)
}

// MARK: - Coach mastery (consistency, forgiving of fumbles)

print("\n== Coach mastery ==")
do {
    let store = MasteryStore()
    let graph = SkillGraph.beginnerGraph()
    let cId = SkillID.chord(.c)

    func states(_ scores: [Double]) -> ([SkillID: MasteryState], Date) {
        var obs: [Observation] = []
        var t = 1_000_000.0
        for s in scores {
            obs.append(Observation(timestamp: Date(timeIntervalSince1970: t),
                implicatedSkills: [cId],
                context: .init(isolation: .isolated, bpm: nil, source: .practice),
                scores: ScoreAxes(accuracy: s, cleanliness: s, timing: s)))
            t += 60
        }
        let now = Date(timeIntervalSince1970: t)
        return (store.project(obs, graph: graph, now: now), now)
    }
    func mastered(_ scores: [Double]) -> Bool {
        let (st, now) = states(scores); return store.isMastered(cId, in: st, now: now)
    }

    check("2 clean reps → not yet mastered", !mastered([0.9, 0.9]))
    check("3 clean reps → mastered", mastered([0.9, 0.9, 0.9]))
    check("one fumble keeps mastery (3 of last 4 clean)", mastered([0.9, 0.9, 0.9, 0.4]))
    check("two recent fumbles → not mastered", !mastered([0.9, 0.9, 0.9, 0.4, 0.4]))
    check("sustained poor → never mastered", !mastered([0.4, 0.5, 0.4, 0.5]))
    check("recovers after a bad streak", mastered([0.4, 0.4, 0.9, 0.9, 0.9]))

    // Forgiving sensitivity: one fumble only dents the smoothed proficiency.
    let good = states([0.8, 0.8, 0.8]).0[cId]!.proficiencyAtLastPractice
    let dipped = states([0.8, 0.8, 0.8, 0.4]).0[cId]!.proficiencyAtLastPractice
    check("one fumble only dents proficiency", good - dipped < 0.12,
          String(format: "Δ %.3f", good - dipped))
}

// Selection policy produces attemptable recommendations from real observations.
do {
    let store = MasteryStore()
    let graph = SkillGraph.beginnerGraph()
    var obs: [Observation] = []
    var t = 2_000_000.0
    for s in [0.4, 0.45, 0.4] {
        obs.append(Observation(timestamp: Date(timeIntervalSince1970: t),
            implicatedSkills: [.chord(.c)],
            context: .init(isolation: .isolated, bpm: nil, source: .practice),
            scores: ScoreAxes(accuracy: s, cleanliness: s, timing: s)))
        t += 60
    }
    let now = Date(timeIntervalSince1970: t)
    let st = store.project(obs, graph: graph, now: now)
    let recs = SelectionPolicy().recommend(graph: graph, states: st, store: store, now: now)
    check("coach produces recommendations", !recs.isEmpty)
    check("recommendations are attemptable (prereqs met)",
          recs.allSatisfy { r in graph.prerequisitesMet(r.id) { store.isMastered($0, in: st, now: now) } })
}

// MARK: - BeatClock (metronome / timing grid)

print("\n== BeatClock ==")
do {
    let clock = BeatClock(bpm: 60)   // 1.0s per beat
    check("60 bpm → 1.0s beat", abs(clock.beatInterval - 1.0) < 1e-9)
    check("on the beat → alignment 1.0", abs(clock.alignment(elapsed: 0) - 1.0) < 1e-9)
    check("on a later beat → alignment 1.0", abs(clock.alignment(elapsed: 3.0) - 1.0) < 1e-9)
    check("half-beat off → alignment 0", clock.alignment(elapsed: 0.5) < 0.01)
    check("quarter-beat off → ~0.5", abs(clock.alignment(elapsed: 0.25) - 0.5) < 0.01)
    check("slightly late → high alignment", clock.alignment(elapsed: 0.95) > 0.85)
    check("beat index", clock.beatIndex(elapsed: 2.5) == 2)

    let fast = BeatClock(bpm: 120)   // 0.5s per beat
    check("120 bpm → 0.5s beat", abs(fast.beatInterval - 0.5) < 1e-9)
    check("120 bpm on beat → 1.0", abs(fast.alignment(elapsed: 1.0) - 1.0) < 1e-9)
}

// MARK: - Transition drill (schedule + observations)

print("\n== Transition drill ==")
do {
    let sched = DrillSchedule(totalReps: 4)
    check("downbeat 1 = count-in (nothing)", sched.step(downbeat: 1) == .init(recordRep: nil, startRep: nil, finished: false))
    check("downbeat 2 starts rep 0", sched.step(downbeat: 2) == .init(recordRep: nil, startRep: 0, finished: false))
    check("downbeat 3 records 0, starts 1", sched.step(downbeat: 3) == .init(recordRep: 0, startRep: 1, finished: false))
    check("downbeat 6 records last & finishes", sched.step(downbeat: 6) == .init(recordRep: 3, startRep: nil, finished: true))

    let seq = transitionSequence(from: .c, to: .g, reps: 4)
    check("sequence alternates", seq == [.c, .g, .c, .g])

    // A transition rep implicates the change, both chords, and the tempo.
    let svc = ScoringService()
    let obs = svc.observation(
        for: .g, previous: .c,
        axes: ScoreAxes(accuracy: 0.8, cleanliness: 0.8, timing: 0.7),
        context: .init(isolation: .inSequence, bpm: 60, source: .practice),
        now: Date(timeIntervalSince1970: 0))
    let ids = Set(obs.implicatedSkills.map { $0.rawValue })
    check("rep implicates the C→G transition", ids.contains("transition.C-G"))
    check("rep implicates both chords", ids.contains("chord.G") && ids.contains("chord.C"))
    check("rep implicates the tempo hold", ids.contains("tempo.60"))
}

// MARK: - SkillDetail (four-axis breakdown)

print("\n== SkillDetail ==")
do {
    func obs(acc: Double, clean: Double, timing: Double, inSeq: Bool, t: Double) -> Observation {
        Observation(timestamp: Date(timeIntervalSince1970: t),
            implicatedSkills: [.chord(.c)],
            context: .init(isolation: inSeq ? .inSequence : .isolated, bpm: inSeq ? 60 : nil, source: .practice),
            scores: ScoreAxes(accuracy: acc, cleanliness: clean, timing: timing))
    }
    // Newest first: one clean untimed, one poor untimed, one clean timed drill rep.
    let observations = [
        obs(acc: 0.9, clean: 0.9, timing: 0.9, inSeq: false, t: 300),   // overall 0.9 → clean
        obs(acc: 0.4, clean: 0.4, timing: 0.4, inSeq: false, t: 200),   // overall 0.4 → not clean
        obs(acc: 0.8, clean: 0.8, timing: 0.7, inSeq: true,  t: 100),   // overall ~0.77 → clean, timed
    ]
    let d = SkillDetail.make(observations: observations, state: nil, mastered: false,
                             masteryThreshold: 0.75, now: Date(timeIntervalSince1970: 400))
    check("counts all attempts", d.attempts == 3)
    check("averages accuracy", abs(d.accuracy - (0.9 + 0.4 + 0.8) / 3) < 1e-9)
    check("timing only from timed reps", abs(d.timing - 0.7) < 1e-9)
    check("hasTiming true when a drill rep exists", d.hasTiming)
    check("consistency = fraction clean", abs(d.consistency - (2.0 / 3.0)) < 1e-9)

    // Untimed-only → no timing dimension.
    let untimed = [obs(acc: 0.9, clean: 0.9, timing: 0.0, inSeq: false, t: 100)]
    check("no timing without drill reps", SkillDetail.make(observations: untimed, state: nil,
        mastered: false, masteryThreshold: 0.75, now: Date(timeIntervalSince1970: 200)).hasTiming == false)
}

// MARK: - Streak (forgiveness)

print("\n== Streak ==")
check("no days → 0", StreakCalculator.current(days: [], today: 10) == 0)
check("today done → 1", StreakCalculator.current(days: [10], today: 10) == 1)
check("three in a row → 3", StreakCalculator.current(days: [8, 9, 10], today: 10) == 3)
check("today not done, alive from yesterday", StreakCalculator.current(days: [9], today: 10) == 1)
check("one-day gap bridged by freeze", StreakCalculator.current(days: [8, 10], today: 10) == 2)
check("two-day gap breaks", StreakCalculator.current(days: [7, 10], today: 10) == 1)
check("freeze covers yesterday when today undone",
      StreakCalculator.current(days: [8], today: 10) == 1)

// MARK: - Session generator

print("\n== Session generator ==")
do {
    let gen = SessionGenerator()
    let graph = SkillGraph.beginnerGraph()
    let store = MasteryStore()

    // Cold start: no observations.
    let cold = gen.plan(graph: graph, states: [:], store: store, now: Date(timeIntervalSince1970: 0))
    check("session starts with tune", cold.first?.kind == .tune)
    check("session ends on a win", cold.last?.kind == .win)
    check("cold-start win is an easy chord", cold.last?.activity == .chord(.em))
    check("cold start has a focus block", cold.contains { $0.kind == .focus })

    // After mastering C, the win targets it.
    var obs: [Observation] = []
    var t = 5_000_000.0
    for _ in 0..<3 {
        obs.append(Observation(timestamp: Date(timeIntervalSince1970: t),
            implicatedSkills: [.chord(.c)],
            context: .init(isolation: .isolated, bpm: nil, source: .practice),
            scores: ScoreAxes(accuracy: 0.95, cleanliness: 0.95, timing: 0.95)))
        t += 60
    }
    let now = Date(timeIntervalSince1970: t)
    let states = store.project(obs, graph: graph, now: now)
    let warm = gen.plan(graph: graph, states: states, store: store, now: now)
    check("win targets a mastered chord", warm.last?.activity == .chord(.c))
}

// MARK: - Structured path (gating ladder)

print("\n== Structured path ==")
do {
    let stages = Stage.beginnerStages
    // Nothing mastered: first stage active, rest locked.
    let none = computeStagePlans(stages, isMastered: { _ in false }, proficiency: { _ in 0 })
    check("first stage active at start", none[0].state == .active)
    check("second stage locked at start", none[1].state == .locked)

    // Master stage 1's skills → stage 1 complete, stage 2 unlocks.
    let s1 = Set(stages[0].skills.map { $0.rawValue })
    let plans = computeStagePlans(stages,
        isMastered: { s1.contains($0.rawValue) }, proficiency: { s1.contains($0.rawValue) ? 1 : 0 })
    check("stage 1 complete once its skills mastered", plans[0].state == .complete)
    check("stage 2 becomes active", plans[1].state == .active)
    check("stage 3 still locked", plans[2].state == .locked)
    check("completed stage shows full progress", plans[0].progress == 1.0)
}

// MARK: - Tips (daily rotation)

print("\n== Tips ==")
do {
    let n = Tip.library.count
    check("library is non-empty", n > 0)
    check("daily is stable within a day", Tip.daily(day: 42).id == Tip.daily(day: 42).id)
    check("daily cycles over the library", Tip.daily(day: 0).id == Tip.daily(day: n).id)
    check("consecutive days differ", Tip.daily(day: 3).id != Tip.daily(day: 4).id)
    check("negative day ordinal is safe", Tip.daily(day: -1).id == Tip.library[n - 1].id)
}

// MARK: - Summary

print("\n\(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")")
exit(failures == 0 ? 0 : 1)
