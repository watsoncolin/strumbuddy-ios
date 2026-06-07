import SwiftUI

/// App entry point.
///
/// Strumbuddy is built around a single shared audio engine (see `Audio/`) and an
/// adaptive coach (see `Coach/`). The three top-level surfaces — Structured Path,
/// Practice (the coach), and Free Play — are thin UIs over that shared core.
/// See `docs/design-doc.md` §3.
@main
struct StrumbuddyApp: App {
    /// App-wide singletons, created once and injected into the view tree.
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(environment)
                .tint(Theme.accent)
        }
    }
}

/// Owns the long-lived services so they survive view recreation.
/// Wiring is intentionally simple for v0.1; swap for a DI container if it grows.
@MainActor
final class AppEnvironment: ObservableObject {
    let audioEngine: AudioEngine
    let coach: Coach
    let metronome: Metronome
    let tracker: PracticeTracker

    init() {
        let log = ObservationLog()
        let graph = SkillGraph.beginnerGraph()
        self.audioEngine = AudioEngine()
        self.coach = Coach(graph: graph, log: log)
        self.metronome = Metronome()
        self.tracker = PracticeTracker()
    }
}
