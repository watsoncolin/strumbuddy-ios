import SwiftUI

/// The structured path (design-doc §3 mode 1): staged milestones the user checks
/// off via a test. Passing a milestone is a threshold on the engine's scores and
/// gates the next stage. v0.1 scaffold: renders the stages and their lock state.
struct StructuredPathView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        NavigationStack {
            List {
                ForEach(Stage.beginnerStages) { stage in
                    StageRow(stage: stage, coach: env.coach)
                }
            }
            .navigationTitle("Your Path")
        }
    }
}

/// A milestone stage. Mastery of its skills (per the coach) decides completion.
struct Stage: Identifiable {
    let id: Int
    let title: String
    let blurb: String
    let skills: [SkillID]

    static let beginnerStages: [Stage] = [
        Stage(id: 1, title: "First chords", blurb: "Em, C, and G — clean and ringing.",
              skills: [.chord(.em), .chord(.c), .chord(.g)]),
        Stage(id: 2, title: "First changes", blurb: "Switch between them in time.",
              skills: [.transition(from: .em, to: .c), .transition(from: .c, to: .g)]),
        Stage(id: 3, title: "Keep the beat", blurb: "Hold a change at 60 bpm.",
              skills: [.tempoHold(60)]),
        Stage(id: 4, title: "Widen the vocabulary", blurb: "Add D and A.",
              skills: [.chord(.d), .chord(.a), .transition(from: .g, to: .d)]),
    ]
}

private struct StageRow: View {
    let stage: Stage
    @ObservedObject var coach: Coach

    private var progress: Double {
        guard !stage.skills.isEmpty else { return 0 }
        let total = stage.skills.reduce(0.0) { $0 + coach.proficiency($1) }
        return total / Double(stage.skills.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(stage.title).font(.headline)
                Spacer()
                if progress >= 0.75 {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.clean)
                }
            }
            Text(stage.blurb).font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: progress).tint(Theme.accent)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    StructuredPathView()
        .environmentObject(AppEnvironment())
}
