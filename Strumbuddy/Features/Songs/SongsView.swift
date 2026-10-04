import SwiftUI

/// The built-in play-along songs — the motivation payoff (wiki: Learning Philosophy,
/// "a real song ASAP"). Each row shows your best stars and whether you already have
/// the chords, so a song reads as a goal rather than a wall.
struct SongsView: View {
    @ObservedObject var coach: Coach
    @ObservedObject var progress: SongProgressStore

    var body: some View {
        NavigationStack {
            List {
                if let goal = progress.goalSong {
                    Section("Your goal") { row(goal) }
                }
                Section {
                    ForEach(Song.library.filter { $0.id != progress.goalSongID }) { row($0) }
                } header: {
                    Text("Play-along")
                } footer: {
                    Text("Traditional songs, chords only. StrumBuddy listens and grades every bar.")
                }
            }
            .navigationTitle("Songs")
        }
    }

    private func row(_ song: Song) -> some View {
        NavigationLink {
            SongDetailView(song: song)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(song.title).font(.headline)
                    Spacer()
                    if let best = progress.bests[song.id] {
                        StarsView(count: SongReport.stars(for: best)).font(.caption)
                    }
                }
                Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
                readiness(song)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    /// "Ready to play" when every chord is mastered, otherwise which ones are new.
    private func readiness(_ song: Song) -> some View {
        let toLearn = song.allChords.filter { !coach.isMastered(.chord($0)) }
        return HStack(spacing: Theme.Spacing.xs) {
            Text(song.allChords.map(\.displayName).joined(separator: " · "))
                .foregroundStyle(Theme.accent)
            if toLearn.isEmpty {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.clean)
            } else {
                Text("· learning \(toLearn.map(\.displayName).joined(separator: ", "))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }
}

/// 0–3 filled stars.
struct StarsView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .foregroundStyle(i < count ? Color.orange : Color.secondary.opacity(0.4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 stars")
    }
}
