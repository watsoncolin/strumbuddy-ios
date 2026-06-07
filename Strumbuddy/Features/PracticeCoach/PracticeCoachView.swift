import SwiftUI

/// The adaptive-coach surface — the "work on…" screen (design-doc §3 mode 2, §5).
/// Observes the `Coach` directly so recommendations and mastery update live as you
/// record attempts in Chord Check.
struct PracticeCoachView: View {
    @ObservedObject var coach: Coach

    var body: some View {
        NavigationStack {
            List {
                Section("Work on this next") {
                    if coach.recommendations.isEmpty {
                        emptyState
                    } else {
                        ForEach(coach.recommendations) { RecommendationRow(rec: $0) }
                    }
                }

                Section("Your chords") {
                    ForEach(Chord.allCases) { chord in
                        ChordMasteryRow(name: chord.displayName,
                                        proficiency: coach.proficiency(.chord(chord)))
                    }
                }
            }
            .navigationTitle("Practice")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "waveform").font(.largeTitle).foregroundStyle(.secondary)
            Text("Let's find your starting point").font(.headline)
            Text("Play a few chords in Chord Check and Strumbuddy will spot what to work on next.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
    }
}

/// One coach recommendation, surfacing the reason so the coach isn't a black box.
private struct RecommendationRow: View {
    let rec: SelectionPolicy.Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(rec.skill.displayName).font(.headline)
            Text("Because \(rec.reason).")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// Per-chord mastery so practice visibly counts.
private struct ChordMasteryRow: View {
    let name: String
    let proficiency: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Text(name).font(.headline).frame(width: 44, alignment: .leading)
            ProgressView(value: min(max(proficiency, 0), 1)).tint(Theme.accent)
            Text("\(Int(proficiency * 100))%")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    PracticeCoachView(coach: AppEnvironment().coach)
}
