import SwiftUI

/// The structured path (design-doc §3 mode 1): a Couch-to-5K-style ladder. Stages
/// unlock in sequence; a stage completes when its skills are mastered (consistency).
/// The active stage is actionable — each skill launches the right pre-targeted tool.
struct StructuredPathView: View {
    @ObservedObject var coach: Coach
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        NavigationStack {
            List {
                ForEach(coach.stagePlans()) { plan in
                    StageRow(plan: plan, coach: coach)
                }
            }
            .navigationTitle("Your Path")
        }
    }
}

private struct StageRow: View {
    let plan: StagePlan
    @ObservedObject var coach: Coach
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Image(systemName: icon).foregroundStyle(iconColor)
                Text(plan.stage.title).font(.headline)
                    .foregroundStyle(plan.state == .locked ? .secondary : .primary)
                Spacer()
            }
            Text(plan.stage.blurb).font(.subheadline).foregroundStyle(.secondary)

            if plan.state != .locked {
                ProgressView(value: plan.progress).tint(Theme.accent)
            }

            // The active stage is actionable: practice each of its skills.
            if plan.state == .active {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(plan.stage.skills, id: \.rawValue) { skill in
                        skillRow(skill)
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .opacity(plan.state == .locked ? 0.5 : 1)
    }

    @ViewBuilder
    private func skillRow(_ id: SkillID) -> some View {
        HStack {
            Image(systemName: coach.isMastered(id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(coach.isMastered(id) ? Theme.clean : .secondary)
            Text(coach.graph.skill(id)?.displayName ?? "")
                .font(.subheadline)
            Spacer()
            NavigationLink {
                practiceDestination(for: id)
            } label: {
                Text("Practice").font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func practiceDestination(for id: SkillID) -> some View {
        switch coach.graph.skill(id)?.kind {
        case .chord(let c):
            ChordCheckView(engine: env.audioEngine, coach: env.coach, initialChord: c)
                .padding(.top).navigationTitle(c.displayName).navigationBarTitleDisplayMode(.inline)
        case .transition(let a, let b):
            TransitionDrillView(metronome: env.metronome, engine: env.audioEngine,
                                coach: env.coach, from: a, to: b)
        case .tempoHold(let bpm):
            TransitionDrillView(metronome: env.metronome, engine: env.audioEngine,
                                coach: env.coach, bpm: bpm)
        default:
            Text("Coming soon")
        }
    }

    private var icon: String {
        switch plan.state {
        case .complete: return "checkmark.seal.fill"
        case .active:   return "play.circle.fill"
        case .locked:   return "lock.fill"
        }
    }

    private var iconColor: Color {
        switch plan.state {
        case .complete: return Theme.clean
        case .active:   return Theme.accent
        case .locked:   return .secondary
        }
    }
}
