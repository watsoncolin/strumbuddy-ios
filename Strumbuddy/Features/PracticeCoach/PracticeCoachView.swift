import SwiftUI

/// The adaptive-coach surface — the "work on…" screen (design-doc §3 mode 2, §5).
/// Shows the coach's ranked recommendations, each with its reasoning (explainability).
struct PracticeCoachView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        NavigationStack {
            List {
                if env.coach.recommendations.isEmpty {
                    VStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "waveform")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Let's find your starting point")
                            .font(.headline)
                        Text("Play a little and Strumbuddy will spot what to work on next.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xl)
                } else {
                    Section("Work on this next") {
                        ForEach(env.coach.recommendations) { rec in
                            RecommendationRow(rec: rec)
                        }
                    }
                }
            }
            .navigationTitle("Practice")
        }
    }
}

/// One coach recommendation, surfacing the reason so the coach isn't a black box.
private struct RecommendationRow: View {
    let rec: SelectionPolicy.Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(rec.skill.displayName)
                .font(.headline)
            Text("Because \(rec.reason).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    PracticeCoachView()
        .environmentObject(AppEnvironment())
}
