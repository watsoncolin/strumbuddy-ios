import SwiftUI

/// A song's chord chart, a graded play-along, and the end-of-song summary. Reads the
/// shared services from the environment and hands them to the session-owning body.
struct SongDetailView: View {
    let song: Song
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        SongPlayAlongView(song: song, engine: env.audioEngine, metronome: env.metronome,
                          coach: env.coach, progress: env.songProgress)
    }
}

/// The play-along runs on `DrillSession` with the song's progression as a fixed
/// sequence: one chord per bar after a count-in, each bar graded (accuracy +
/// cleanliness + timing) and logged to the coach as in-song evidence.
private struct SongPlayAlongView: View {
    let song: Song
    @StateObject private var session: DrillSession
    @ObservedObject private var engine: AudioEngine
    @ObservedObject private var coach: Coach
    @ObservedObject private var progress: SongProgressStore
    private let metronome: Metronome

    @State private var fullSpeed = false
    @State private var newBest = false

    init(song: Song, engine: AudioEngine, metronome: Metronome, coach: Coach,
         progress: SongProgressStore) {
        self.song = song
        self.engine = engine
        self.metronome = metronome
        self.coach = coach
        self.progress = progress
        _session = StateObject(wrappedValue: DrillSession(
            metronome: metronome, engine: engine, coach: coach,
            bpm: Self.practiceBPM(for: song), fixedSequence: song.flatChords, source: .song))
    }

    /// Beginners rarely manage a song at full tempo straight away; practice at ~70%.
    static func practiceBPM(for song: Song) -> Int {
        max(50, Int((Double(song.bpm) * 0.7 / 5).rounded()) * 5)
    }

    private var bpm: Int { fullSpeed ? song.bpm : Self.practiceBPM(for: song) }
    private var report: SongReport { SongReport(bars: session.results) }

    var body: some View {
        Group {
            switch session.phase {
            case .setup:             chart
            case .countIn, .playing: playAlong
            case .finished:          summary
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { session.stop(); engine.stop() }
        .onChange(of: session.phase) { phase in
            guard phase == .finished else { return }
            engine.stop()
            newBest = progress.record(score: report.score, for: song)
        }
    }

    private func play() {
        session.bpm = bpm
        newBest = false
        Task {
            await engine.start()
            session.start()
        }
    }

    // MARK: Chart

    private var chart: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
                    if let best = progress.bests[song.id] {
                        HStack(spacing: Theme.Spacing.s) {
                            StarsView(count: SongReport.stars(for: best))
                            Text("Best \(Int(best * 100))%").foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }

                Text("Chords in this song").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        ForEach(song.allChords) { chordCard($0) }
                    }
                }

                ForEach(song.sections) { section in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text(section.name).font(.headline)
                        barGrid(section.chords.map { ($0, nil) })
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Picker("Speed", selection: $fullSpeed) {
                        Text("Practice · \(Self.practiceBPM(for: song)) bpm").tag(false)
                        Text("Full · \(song.bpm) bpm").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Button(action: play) {
                        Label("Play along", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    goalButton
                }
            }
            .padding()
        }
    }

    private func chordCard(_ chord: Chord) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            ChordDiagramView(chord: chord).frame(width: 80, height: 104)
            HStack(spacing: 4) {
                Text(chord.displayName).font(.caption).bold()
                if coach.isMastered(.chord(chord)) {
                    Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(Theme.clean)
                }
            }
            ChordPreviewButton(chord: chord)
        }
    }

    private var goalButton: some View {
        let isGoal = progress.goalSongID == song.id
        return Button {
            progress.setGoal(isGoal ? nil : song)
        } label: {
            Label(isGoal ? "This is your goal song" : "Make this my goal",
                  systemImage: isGoal ? "flag.fill" : "flag")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Your daily sessions will focus on this song's chords and changes.")
    }

    /// One chip per bar; when graded, tinted by how the bar went.
    private func barGrid(_ bars: [(Chord, Double?)], highlight: Int? = nil) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Theme.Spacing.s) {
            ForEach(bars.indices, id: \.self) { i in
                let (chord, score) = bars[i]
                Text(chord.displayName)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(chipColor(score).opacity(0.15),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .stroke(i == highlight ? Theme.accent : .clear, lineWidth: 2))
            }
        }
    }

    private func chipColor(_ score: Double?) -> Color {
        guard let score else { return Theme.accent }
        return score >= SongReport.cleanThreshold ? Theme.clean : (score >= 0.5 ? Theme.shaky : Theme.missed)
    }

    // MARK: Play-along

    private var playAlong: some View {
        VStack(spacing: Theme.Spacing.l) {
            beatDots
            if session.phase == .countIn {
                Text("Get ready…").font(.title2).foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else if let chord = session.currentChord {
                Text("Bar \(session.currentRep + 1) of \(session.totalReps)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(chord.displayName).font(.system(size: 64, weight: .bold, design: .rounded))
                ChordDiagramView(chord: chord).frame(width: 130, height: 168)
                if let next = session.nextChord {
                    Text(next == chord ? "Hold it…" : "Next: \(next.displayName)")
                        .font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                barGrid(gradedBars, highlight: session.currentRep)
            }
            Button("Stop") { session.stop(); engine.stop() }.tint(.secondary)
        }
        .padding()
    }

    /// Every bar of the song, with scores filled in as bars finish.
    private var gradedBars: [(Chord, Double?)] {
        let scores = Dictionary(uniqueKeysWithValues: session.results.map { ($0.id, $0.axes.overall) })
        return song.flatChords.enumerated().map { ($1, scores[$0]) }
    }

    private var beatDots: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(1...4, id: \.self) { beat in
                Circle()
                    .fill(session.beatInBar == beat ? (beat == 1 ? Theme.accent : Theme.clean)
                                                    : Color.secondary.opacity(0.2))
                    .frame(width: 14, height: 14)
            }
        }
    }

    // MARK: Summary

    private var summary: some View {
        let report = self.report
        return ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                StarsView(count: report.stars).font(.largeTitle)
                Text(headline(report)).font(.title2).bold().multilineTextAlignment(.center)
                Text("\(Int(report.score * 100))% · \(session.bpm) bpm")
                    .font(.subheadline).foregroundStyle(.secondary)
                if newBest {
                    Label("New personal best!", systemImage: "trophy.fill")
                        .font(.subheadline).foregroundStyle(.orange)
                }

                barGrid(gradedBars)

                if let change = report.trickiestChange {
                    trickiestCard(change)
                } else if !report.bars.isEmpty {
                    Label("Every change was clean.", systemImage: "checkmark.seal.fill")
                        .font(.subheadline).foregroundStyle(Theme.clean)
                }

                HStack(spacing: Theme.Spacing.l) {
                    Button("Chart") { session.reset() }.buttonStyle(.bordered)
                    Button("Play again", action: play).buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private func headline(_ r: SongReport) -> String {
        switch r.stars {
        case 3:  return "You played \(song.title)!"
        case 2:  return "Sounding like a song!"
        case 1:  return "You made it through!"
        default: return "Good first run — it gets easier."
        }
    }

    /// The coach's diagnosis for this run, with a one-tap drill on exactly that change.
    private func trickiestCard(_ change: SongReport.Change) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Trickiest change", systemImage: "scope").font(.caption).foregroundStyle(Theme.accent)
            Text("\(change.from.displayName) → \(change.to.displayName) averaged \(Int(change.score * 100))%. Drill it slowly and the whole song comes together.")
                .font(.subheadline)
            NavigationLink {
                TransitionDrillView(metronome: metronome, engine: engine, coach: coach,
                                    from: change.from, to: change.to)
            } label: {
                Label("Drill \(change.from.displayName) → \(change.to.displayName)", systemImage: "metronome")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
