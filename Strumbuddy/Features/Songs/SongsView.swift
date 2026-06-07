import SwiftUI

/// Browse the built-in play-along songs — the motivation payoff (play a real song).
struct SongsView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AnalyzeView()
                    } label: {
                        Label("Analyze your own song (beta)", systemImage: "waveform.badge.magnifyingglass")
                    }
                }

                Section("Play-along") {
                    ForEach(Song.library) { song in
                        NavigationLink {
                            SongDetailView(song: song, metronome: env.metronome)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(song.title).font(.headline)
                                Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
                                Text(song.allChords.map(\.displayName).joined(separator: " · "))
                                    .font(.caption).foregroundStyle(Theme.accent)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                    }
                }
            }
            .navigationTitle("Songs")
        }
    }
}
