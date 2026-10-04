import SwiftUI

/// "How far have I come?" — the answer a beginner needs around week three, when
/// motivation dips (design-doc §1, retention). Headline numbers as tiles, then the
/// practice rhythm and the one-minute-changes benchmark over time.
struct YourProgressView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        ProgressContent(coach: env.coach, log: env.coach.log, tracker: env.tracker,
                        oneMinute: env.oneMinute)
    }
}

private struct ProgressContent: View {
    @ObservedObject var coach: Coach
    @ObservedObject var log: ObservationLog
    @ObservedObject var tracker: PracticeTracker
    @ObservedObject var oneMinute: OneMinuteStore

    @State private var pair: String?

    private let activityDays = 28

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                tiles
                section("Practice, last \(activityDays) days") {
                    ActivityChart(days: ProgressStats.dailyAttempts(log.entries, days: activityDays, now: Date()))
                        .frame(height: 160)
                }
                oneMinuteSection
            }
            .padding()
        }
        .navigationTitle("Your progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Tiles

    private var tiles: some View {
        let chords = Chord.allCases.filter { coach.isMastered(.chord($0)) }.count
        let changes = coach.graph.skills.values.filter {
            if case .transition = $0.kind { return coach.isMastered($0.id) } else { return false }
        }.count
        let totalChanges = coach.graph.skills.values.filter {
            if case .transition = $0.kind { return true } else { return false }
        }.count
        let daysThisMonth = tracker.recentCompletions(days: 30).filter { $0 }.count

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.m) {
            StatTile(value: "\(tracker.streak)", label: "day streak", icon: "flame.fill")
            StatTile(value: "\(daysThisMonth)", label: "days practiced, last 30", icon: "calendar")
            StatTile(value: "\(chords)/\(Chord.allCases.count)", label: "chords mastered", icon: "hand.raised.fingers.spread")
            StatTile(value: "\(changes)/\(totalChanges)", label: "changes mastered", icon: "arrow.left.arrow.right")
        }
    }

    // MARK: One-minute changes

    @ViewBuilder
    private var oneMinuteSection: some View {
        let pairs = oneMinute.pairs
        section("One-minute changes") {
            if pairs.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("How many clean changes can you make in a minute? Try it once a day and watch the number climb.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink { OneMinuteChangesView() } label: {
                        Label("Try one-minute changes", systemImage: "timer")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                let current = pair.flatMap { pairs.contains($0) ? $0 : nil } ?? pairs[0]
                if pairs.count > 1 {
                    Picker("Chords", selection: Binding(get: { current }, set: { pair = $0 })) {
                        ForEach(pairs, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                let history = oneMinute.history(for: current)
                if history.count >= 2 {
                    OneMinuteChart(history: history).frame(height: 180)
                }
                HStack {
                    Text("Best \(oneMinute.best(for: current) ?? 0) · last \(history.last?.changes ?? 0)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    NavigationLink { OneMinuteChangesView() } label: {
                        Label("Go", systemImage: "timer")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title).font(.headline)
            content()
        }
    }
}

/// A headline number. Value in primary ink, label muted; the icon carries the accent.
private struct StatTile: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(value).font(.system(.title, design: .rounded)).bold().monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
