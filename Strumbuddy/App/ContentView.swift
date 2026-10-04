import SwiftUI

/// The three modes, one engine (design-doc §3), plus the daily session and songs.
struct ContentView: View {
    enum Tab: Hashable { case today, path, practice, songs, freePlay }

    @EnvironmentObject private var env: AppEnvironment
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var selection: Tab = .today

    var body: some View {
        tabs
            .fullScreenCover(isPresented: Binding(
                get: { !onboardingComplete },
                set: { presented in onboardingComplete = !presented })
            ) {
                OnboardingView(engine: env.audioEngine, notifications: env.notifications) {
                    onboardingComplete = true
                }
            }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            TodayView(coach: env.coach, tracker: env.tracker, notifications: env.notifications)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            StructuredPathView(coach: env.coach)
                .tabItem { Label("Path", systemImage: "map") }
                .tag(Tab.path)

            PracticeCoachView(coach: env.coach)
                .tabItem { Label("Practice", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.practice)

            SongsView(coach: env.coach, progress: env.songProgress)
                .tabItem { Label("Songs", systemImage: "music.note.list") }
                .tag(Tab.songs)

            FreePlayView()
                .tabItem { Label("Free Play", systemImage: "guitars") }
                .tag(Tab.freePlay)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppEnvironment())
}
