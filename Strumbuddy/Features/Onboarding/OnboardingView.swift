import SwiftUI

/// First-run onboarding (wiki: Daily Practice Loop). Scripted to manufacture a
/// session-one win: hear the guitar (the app's magic), then play a first chord (Em)
/// and get celebrated. Low bars + a Skip on every audio step so nobody gets stuck.
struct OnboardingView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var notifications: NotificationService
    let coach: Coach
    let onFinish: () -> Void

    enum Step: Int, CaseIterable { case welcome, experience, listen, firstChord, reminder, ready }
    @State private var step: Step = .welcome
    @State private var heardSomething = false
    @State private var playedChord = false
    @State private var playedBefore = false
    @State private var knownChords: Set<Chord> = []

    /// A modest bar so a beginner's first (buzzy) Em still counts as a win.
    private let chordWinThreshold = 0.55

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            progressDots
            Spacer(minLength: 0)
            content
            Spacer()
            footer
        }
        .padding()
        .onDisappear { engine.setTargetChord(nil); engine.stop() }
        .onChange(of: step) { handleStep($0) }
        .onChange(of: engine.fundamental) { value in
            if step == .listen, value != nil { heardSomething = true }
        }
        .onChange(of: engine.targetScore) { value in
            if step == .firstChord, (value?.confidence ?? 0) >= chordWinThreshold { playedChord = true }
        }
        .animation(.easeInOut, value: step)
        .animation(.easeInOut, value: heardSomething)
        .animation(.easeInOut, value: playedChord)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            page(icon: "guitars.fill",
                 title: "Welcome to StrumBuddy",
                 body: "Learn acoustic guitar, five minutes a day. I listen while you play and coach you on what to work on next.")
        case .experience:
            experience
        case .listen:
            if engine.state == .denied {
                page(icon: "mic.slash",
                     title: "I need to hear you",
                     body: "Enable microphone access for StrumBuddy in Settings, then come back.")
            } else if heardSomething {
                page(icon: "waveform",
                     title: "I can hear you! 🎸",
                     body: "That's the whole idea — I listen to your real guitar and give you real feedback.")
            } else {
                page(icon: "waveform",
                     title: "First, let me hear you",
                     body: "Pluck any string on your guitar.")
            }
        case .firstChord:
            VStack(spacing: Theme.Spacing.m) {
                Text(playedChord ? "You played E minor! 🎉" : "Your first chord: E minor")
                    .font(.title2).bold().multilineTextAlignment(.center)
                ChordDiagramView(chord: .em).frame(width: 130, height: 168)
                ChordPreviewButton(chord: .em)
                Text(playedChord
                     ? "That's a real chord. This is how every session works."
                     : "Two fingers on the 2nd fret (A and D strings), then strum.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .reminder:
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "bell.badge.fill").font(.system(size: 56)).foregroundStyle(Theme.accent)
                Text("When should I nudge you?").font(.title2).bold().multilineTextAlignment(.center)
                Text("A daily reminder is the single biggest thing that keeps a habit going. Pick a time you usually have your guitar nearby.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                DatePicker("", selection: $notifications.reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
            }
        case .ready:
            page(icon: "flame.fill",
                 title: "You're all set",
                 body: "Practice a few minutes a day and your streak grows. Each session ends on something you can already do.")
        }
    }

    /// Placement: brand new, or "I know some chords" → pick them. Picked chords start
    /// as mastered (see `Placement`), so the path skips what you already have.
    private var experience: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "hand.wave.fill").font(.system(size: 56)).foregroundStyle(Theme.accent)
            Text("Have you played before?").font(.title2).bold().multilineTextAlignment(.center)
            Picker("Experience", selection: $playedBefore) {
                Text("I'm brand new").tag(false)
                Text("I know some chords").tag(true)
            }
            .pickerStyle(.segmented)
            if playedBefore {
                Text("Tap the chords you can already play cleanly. I'll check them in your first few sessions.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Theme.Spacing.s) {
                    ForEach(Chord.allCases) { chord in
                        let on = knownChords.contains(chord)
                        Button {
                            if on { knownChords.remove(chord) } else { knownChords.insert(chord) }
                        } label: {
                            Text(chord.displayName).font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.s)
                                .background(on ? Theme.accent : Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(on ? .white : .primary)
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            } else {
                Text("Perfect — we'll start from your very first chord.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    private func page(icon: String, title: String, body: String) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(Theme.accent)
            Text(title).font(.title2).bold().multilineTextAlignment(.center)
            Text(body).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    // MARK: Footer (advance / skip)

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .welcome:
            primary("Get started") { step = .experience }
        case .experience:
            primary("Continue") {
                if playedBefore { coach.place(knownChords: Chord.allCases.filter(knownChords.contains)) }
                step = .listen
            }
        case .listen:
            if heardSomething { primary("Continue") { step = .firstChord } }
            else { skip("Skip") { step = .firstChord } }
        case .firstChord:
            if playedChord { primary("Continue") { step = .reminder } }
            else { skip("Skip for now") { step = .reminder } }
        case .reminder:
            VStack(spacing: Theme.Spacing.s) {
                primary("Remind me daily") { Task { await notifications.enableReminders(); step = .ready } }
                skip("Not now") { step = .ready }
            }
        case .ready:
            primary("Start practicing") { onFinish() }
        }
    }

    private func primary(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    private func skip(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(label, action: action).tint(.secondary)
    }

    private var progressDots: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s.rawValue <= step.rawValue ? Theme.accent : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: Engine lifecycle per step

    private func handleStep(_ s: Step) {
        switch s {
        case .listen:     Task { await engine.start() }   // contextual mic prompt
        case .firstChord: engine.setTargetChord(.em)
        case .reminder:   engine.setTargetChord(nil); engine.stop()
        case .ready:      engine.setTargetChord(nil)
        case .welcome, .experience: break
        }
    }
}
