import SwiftUI

/// The daily session — the home tab and keystone retention surface (wiki: Daily
/// Practice Loop). Three states: a **hero** that makes the streak the centerpiece
/// and offers one tap to start; a full-screen **runner** that plays the coach-built
/// blocks one at a time and auto-advances on engine-verified success; and a
/// **reward** screen that closes on a celebrated win with the day's mastery gains
/// and a preview of tomorrow.
struct TodayView: View {
    @ObservedObject var coach: Coach
    @ObservedObject var tracker: PracticeTracker
    @ObservedObject var notifications: NotificationService
    @EnvironmentObject private var env: AppEnvironment

    private enum Phase { case ready, running, complete }

    @State private var blocks: [SessionBlock] = []
    @State private var currentIndex = 0
    @State private var phase: Phase = .ready
    @State private var justCompleted = false
    @State private var advanceTask: Task<Void, Never>?
    @State private var beforeProficiency: [SkillID: Double] = [:]
    @State private var movers: [Mover] = []
    @State private var showSettings = false

    private struct Mover: Identifiable {
        let id = UUID()
        let name: String
        let delta: Double
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .ready:    heroScreen
                case .running:  runnerScreen
                case .complete: completionScreen
                }
            }
            .navigationTitle("Today")
            .onAppear { if blocks.isEmpty { generate() } }
        }
    }

    // MARK: - Hero (pre-session)

    private var heroScreen: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                streakCenterpiece
                if tracker.freezeUsed {
                    banner("Streak saved — welcome back! A freeze covered your missed day.",
                           icon: "lifepreserver", tint: Theme.accent)
                }
                coachingHeadline
                startButton
                reminderRow
                tipFooter
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(notifications: notifications)
        }
    }

    private var streakCenterpiece: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(tracker.streak > 0 ? .orange : .secondary)
            if tracker.streak > 0 {
                Text("\(tracker.streak)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("day streak").font(.headline).foregroundStyle(.secondary)
            } else {
                Text("Start your streak today").font(.title3).bold()
            }
            weekDots
            if tracker.completedToday {
                Label("Done for today", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).foregroundStyle(Theme.clean)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
    }

    private var weekDots: some View {
        let recent = tracker.recentCompletions(days: 7)
        let labels = weekdayLabels()
        return HStack(spacing: Theme.Spacing.s) {
            ForEach(Array(recent.enumerated()), id: \.offset) { i, done in
                VStack(spacing: 4) {
                    Circle()
                        .fill(done ? Color.orange : Color.secondary.opacity(0.18))
                        .frame(width: 14, height: 14)
                    Text(labels[i]).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var coachingHeadline: some View {
        Group {
            if let focus = blocks.first(where: { $0.kind == .focus })
                        ?? blocks.first(where: { $0.kind == .stretch }) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Label("Today's focus", systemImage: "scope")
                        .font(.caption).foregroundStyle(Theme.accent)
                    Text(focus.detail).font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
    }

    private var startButton: some View {
        Button { beginSession() } label: {
            VStack(spacing: 2) {
                Text(tracker.completedToday ? "Practice again" : "Start today's session")
                    .font(.headline)
                Text("\(blocks.count) steps · about 5 min")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    @ViewBuilder
    private var reminderRow: some View {
        Button { showSettings = true } label: {
            HStack {
                Label(notifications.enabled ? "Daily reminder" : "Turn on a daily reminder",
                      systemImage: notifications.enabled ? "bell.fill" : "bell")
                    .font(.subheadline)
                Spacer()
                if notifications.enabled {
                    Text(notifications.reminderTime, style: .time)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.m)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private var tipFooter: some View {
        NavigationLink { TipsView() } label: {
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
            .background(Theme.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private var todaysTip: Tip {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return Tip.daily(day: day)
    }

    // MARK: - Runner (in-session)

    private var runnerScreen: some View {
        VStack(spacing: Theme.Spacing.m) {
            progressBar
            if blocks.indices.contains(currentIndex) {
                blockRunner(blocks[currentIndex])
            }
        }
        .padding()
        // Pin to the top so a tall tool can't push the progress bar up under the
        // nav header; the tool area itself scrolls within the remaining space.
        .frame(maxHeight: .infinity, alignment: .top)
        // The runner owns the shared engine for the whole session: start once on
        // entry, set the target per block, stop once on exit. Embedded tools don't.
        .task { await env.audioEngine.start(); setTarget(for: currentIndex) }
        .onChange(of: currentIndex) { setTarget(for: $0) }
        .onDisappear { env.audioEngine.setTargetChord(nil); env.audioEngine.stop() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { exitSession() } label: { Image(systemName: "xmark") }
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ProgressView(value: Double(currentIndex), total: Double(max(blocks.count, 1)))
                .tint(Theme.accent)
            Text("Step \(min(currentIndex + 1, blocks.count)) of \(blocks.count)")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func blockRunner(_ block: SessionBlock) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            blockHeader(block)
            ZStack {
                toolArea(for: block)
                    .id(currentIndex)   // fresh tool per block: resets success flags, restarts engine
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if justCompleted { completedOverlay }
            }
            .frame(maxHeight: .infinity)
            if !justCompleted { skipButton }
        }
    }

    /// Tuner/chord tools can grow taller than the screen with live feedback, so they
    /// scroll within the runner; the drill owns its own layout/scrolling.
    @ViewBuilder
    private func toolArea(for block: SessionBlock) -> some View {
        switch block.activity {
        case .transition:
            toolView(for: block)
        default:
            ScrollView {
                toolView(for: block)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
    }

    private func blockHeader(_ block: SessionBlock) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon(block.kind)).font(.title2)
                .foregroundStyle(Theme.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title).font(.headline)
                Text(block.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var completedOverlay: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.clean)
            Text("Nice!").font(.title).bold()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
        .transition(.opacity)
    }

    private var skipButton: some View {
        Button("Skip this step") { completeBlock() }
            .font(.subheadline).tint(.secondary)
    }

    // MARK: - Reward (post-session)

    private var completionScreen: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64)).foregroundStyle(.orange)
                Text("Session complete!").font(.title).bold()
                Text(tracker.streak > 0 ? "Day \(tracker.streak) 🔥" : "Great start!")
                    .font(.title3).foregroundStyle(.secondary)

                if let milestone = milestoneMessage(tracker.streak) {
                    banner(milestone, icon: "trophy.fill", tint: .orange)
                }
                if tracker.freezeUsed {
                    banner("We saved your streak with a freeze — welcome back.",
                           icon: "lifepreserver", tint: Theme.accent)
                }
                if !movers.isEmpty { moversCard }
                tomorrowCard
                if !notifications.enabled { enableReminderCard }

                HStack(spacing: Theme.Spacing.l) {
                    Button("Done") { exitSession() }.buttonStyle(.bordered)
                    Button("Practice again") { beginSession() }.buttonStyle(.borderedProminent)
                }
                .padding(.top, Theme.Spacing.s)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    private var moversCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("You leveled up", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline).foregroundStyle(Theme.clean)
            ForEach(movers) { m in
                HStack {
                    Text(m.name).font(.subheadline)
                    Spacer()
                    Text("+\(Int((m.delta * 100).rounded()))%")
                        .font(.subheadline).bold().monospacedDigit().foregroundStyle(Theme.clean)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.clean.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    @ViewBuilder
    private var tomorrowCard: some View {
        if let next = coach.recommendations.first {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label("Tomorrow", systemImage: "arrow.right.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Next up: \(next.skill.displayName)").font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private var enableReminderCard: some View {
        Button { Task { await notifications.enableReminders() } } label: {
            HStack {
                Label("Get a daily reminder so you don't lose your streak", systemImage: "bell")
                    .font(.footnote)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.m)
            .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private func banner(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.footnote)
            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Tools

    @ViewBuilder
    private func toolView(for block: SessionBlock) -> some View {
        // ownsEngine: false — the runner owns the shared engine's start/stop and
        // target chord (see configureEngine/setTarget). Letting each block's tool
        // manage them caused a cross-block race: a disappearing tool's stop()/clear
        // ran after the next tool's idempotent start() no-op, killing live scoring.
        switch block.activity {
        case .tune:
            TunerView(engine: env.audioEngine, onInTune: { completeBlock() }, ownsEngine: false)
        case .chord(let chord):
            ChordCheckView(engine: env.audioEngine, coach: env.coach,
                           initialChord: chord, onClean: { completeBlock() }, ownsEngine: false)
        case .transition(let from, let to):
            TransitionDrillView(metronome: env.metronome, engine: env.audioEngine,
                                coach: env.coach, from: from, to: to,
                                ownsEngine: false, onComplete: { completeBlock() })
        }
    }

    /// The engine target for a block: the chord for chord blocks, nil for the tuner,
    /// nil for the drill (DrillSession sets per-bar targets while it plays).
    private func setTarget(for index: Int) {
        guard blocks.indices.contains(index) else { return }
        switch blocks[index].activity {
        case .tune:            env.audioEngine.setTargetChord(nil)
        case .chord(let c):    env.audioEngine.setTargetChord(c)
        case .transition:      env.audioEngine.setTargetChord(nil)
        }
    }

    // MARK: - Logic

    private func generate() {
        blocks = coach.todaySession()
    }

    private func beginSession() {
        if blocks.isEmpty { generate() }
        beforeProficiency = snapshotProficiency()
        movers = []
        currentIndex = 0
        justCompleted = false
        withAnimation { phase = .running }
    }

    /// Block done (engine-verified or skipped): flash a confirmation, then advance.
    private func completeBlock() {
        guard phase == .running, !justCompleted else { return }
        advanceTask?.cancel()
        withAnimation { justCompleted = true }
        advanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func advance() {
        withAnimation { justCompleted = false }
        currentIndex += 1
        if currentIndex >= blocks.count { finishSession() }
    }

    private func finishSession() {
        tracker.recordSessionCompleted()
        movers = computeMovers()
        withAnimation { phase = .complete }
    }

    private func exitSession() {
        advanceTask?.cancel()
        justCompleted = false
        generate()   // rebuild for next time so it reflects the mastery we just moved
        withAnimation { phase = .ready }
    }

    private func snapshotProficiency() -> [SkillID: Double] {
        let now = Date()
        var out: [SkillID: Double] = [:]
        for st in coach.mastery.values { out[st.skill] = st.retrievability(at: now) }
        return out
    }

    /// The skills whose mastery rose during this session — the intrinsic reward
    /// that complements the streak (and shows off the coach's per-skill model).
    private func computeMovers() -> [Mover] {
        let now = Date()
        return coach.mastery.values.compactMap { st -> Mover? in
            let after = st.retrievability(at: now)
            let before = beforeProficiency[st.skill] ?? after
            let delta = after - before
            guard delta > 0.02 else { return nil }
            let name = coach.graph.skill(st.skill)?.displayName ?? st.skill.rawValue
            return Mover(name: name, delta: delta)
        }
        .sorted { $0.delta > $1.delta }
        .prefix(3)
        .map { $0 }
    }

    // MARK: - Helpers

    private func icon(_ kind: SessionBlock.Kind) -> String {
        switch kind {
        case .tune:    return "tuningfork"
        case .review:  return "arrow.clockwise"
        case .focus:   return "scope"
        case .stretch: return "arrow.up.forward"
        case .win:     return "star.fill"
        }
    }

    private func milestoneMessage(_ streak: Int) -> String? {
        switch streak {
        case 3:        return "3 days in a row — it's becoming a habit!"
        case 7:        return "A full week! 🎉"
        case 14:       return "Two weeks straight — serious momentum."
        case 30:       return "30 days! You've outlasted most beginners."
        case 50:       return "50-day streak — incredible."
        case 100:      return "100 days. You're a guitarist now."
        case 200, 365: return "\(streak) days. Legendary."
        default:       return nil
        }
    }

    private func weekdayLabels() -> [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols   // ["S","M","T",...]
        let todayIdx = cal.component(.weekday, from: Date()) - 1
        return (0..<7).reversed().map { symbols[((todayIdx - $0) % 7 + 7) % 7] }
    }
}
