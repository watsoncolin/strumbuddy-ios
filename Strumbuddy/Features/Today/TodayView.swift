import SwiftUI

/// The daily session — the home tab and keystone retention surface (wiki: Daily
/// Practice Loop). Shows the streak, runs the coach-built blocks one at a time
/// (each launching the right pre-targeted tool), and ends on a celebrated win.
struct TodayView: View {
    @ObservedObject var coach: Coach
    @ObservedObject var tracker: PracticeTracker
    @EnvironmentObject private var env: AppEnvironment

    @State private var blocks: [SessionBlock] = []
    @State private var currentIndex = 0
    @State private var sessionDone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    streakHeader
                    tipCard
                    if sessionDone {
                        completionCard
                    } else {
                        progressLabel
                        ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                            blockRow(index: index, block: block)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .onAppear { if blocks.isEmpty { generate() } }
        }
    }

    // MARK: Header

    private var streakHeader: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "flame.fill")
                .foregroundStyle(tracker.streak > 0 ? .orange : .secondary)
            Text(tracker.streak > 0 ? "\(tracker.streak)-day streak" : "Start your streak today")
                .font(.headline)
            Spacer()
            if tracker.completedToday {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.clean)
            }
        }
    }

    private var tipCard: some View {
        NavigationLink {
            TipsView()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Label("Tip", systemImage: "lightbulb.fill").font(.caption).foregroundStyle(.orange)
                    Spacer()
                    Text("More tips").font(.caption).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                }
                TipRow(tip: todaysTip)
            }
            .padding(Theme.Spacing.m)
            .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private var todaysTip: Tip {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return Tip.daily(day: day)
    }

    private var progressLabel: some View {
        Text("Step \(min(currentIndex + 1, blocks.count)) of \(blocks.count)")
            .font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Blocks

    @ViewBuilder
    private func blockRow(index: Int, block: SessionBlock) -> some View {
        let state: BlockState = index < currentIndex ? .done : (index == currentIndex ? .active : .upcoming)
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon(block.kind))
                .font(.title3)
                .foregroundStyle(state == .upcoming ? .secondary : Theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(block.title).font(.headline)
                Text(block.detail).font(.subheadline).foregroundStyle(.secondary)

                if state == .active {
                    HStack(spacing: Theme.Spacing.m) {
                        NavigationLink {
                            toolView(for: block)
                        } label: {
                            Label("Practice", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Done") { advance() }
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
            }
            Spacer()
            if state == .done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.clean)
            }
        }
        .padding(Theme.Spacing.m)
        .background(state == .active ? Theme.accent.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .opacity(state == .upcoming ? 0.55 : 1)
    }

    private enum BlockState { case done, active, upcoming }

    private var completionCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56)).foregroundStyle(.orange)
            Text("Session complete!").font(.title2).bold()
            Text(tracker.streak > 0 ? "Day \(tracker.streak) 🔥 — come back tomorrow."
                                    : "Nice work — come back tomorrow.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Practice again") { generate() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: Logic

    private func generate() {
        blocks = coach.todaySession()
        currentIndex = 0
        sessionDone = false
    }

    private func advance() {
        currentIndex += 1
        if currentIndex >= blocks.count {
            tracker.recordSessionCompleted()
            sessionDone = true
        }
    }

    @ViewBuilder
    private func toolView(for block: SessionBlock) -> some View {
        switch block.activity {
        case .tune:
            TunerView(engine: env.audioEngine)
                .navigationTitle("Tune up").navigationBarTitleDisplayMode(.inline)
        case .chord(let chord):
            ChordCheckView(engine: env.audioEngine, coach: env.coach, initialChord: chord)
                .padding(.top).navigationTitle(chord.displayName).navigationBarTitleDisplayMode(.inline)
        case .transition(let from, let to):
            TransitionDrillView(metronome: env.metronome, engine: env.audioEngine,
                                coach: env.coach, from: from, to: to)
        }
    }

    private func icon(_ kind: SessionBlock.Kind) -> String {
        switch kind {
        case .tune:    return "tuningfork"
        case .review:  return "arrow.clockwise"
        case .focus:   return "scope"
        case .stretch: return "arrow.up.forward"
        case .win:     return "star.fill"
        }
    }
}
