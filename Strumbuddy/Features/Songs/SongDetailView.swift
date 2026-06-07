import SwiftUI

/// A song's chord chart + a guided, metronome-driven play-along. Chords only.
struct SongDetailView: View {
    @StateObject private var player: SongPlayer

    init(song: Song, metronome: Metronome) {
        _player = StateObject(wrappedValue: SongPlayer(song: song, metronome: metronome))
    }

    var body: some View {
        Group {
            if player.isPlaying { playAlong } else { chart }
        }
        .navigationTitle(player.song.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    // MARK: Chart

    private var chart: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(player.song.artist).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(player.song.bpm) BPM · chords only").font(.caption).foregroundStyle(.secondary)
                }

                Text("Chords in this song").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(player.song.allChords) { chord in
                            VStack(spacing: Theme.Spacing.xs) {
                                ChordDiagramView(chord: chord).frame(width: 80, height: 104)
                                Text(chord.displayName).font(.caption)
                            }
                        }
                    }
                }

                ForEach(player.song.sections) { section in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text(section.name).font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                                  spacing: Theme.Spacing.s) {
                            ForEach(section.chords.indices, id: \.self) { i in
                                chip(section.chords[i].displayName)
                            }
                        }
                    }
                }

                Button { player.start() } label: {
                    Label("Play along", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: Play-along

    private var playAlong: some View {
        VStack(spacing: Theme.Spacing.l) {
            beatDots
            if let chord = player.current {
                Text(chord.displayName)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                ChordDiagramView(chord: chord).frame(width: 140, height: 180)
            }
            if let next = player.next {
                Text("Next: \(next.displayName)").font(.title3).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Stop") { player.stop() }.tint(.secondary)
        }
        .padding()
    }

    private var beatDots: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(1...4, id: \.self) { beat in
                Circle()
                    .fill(player.beatInBar == beat ? (beat == 1 ? Theme.accent : Theme.clean)
                                                   : Color.secondary.opacity(0.2))
                    .frame(width: 14, height: 14)
            }
        }
    }
}
