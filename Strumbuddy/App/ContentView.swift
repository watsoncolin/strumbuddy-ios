import SwiftUI

/// The three modes, one engine (design-doc §3).
struct ContentView: View {
    enum Tab: Hashable { case today, path, practice, freePlay }

    @EnvironmentObject private var env: AppEnvironment
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var selection: Tab = .today

    var body: some View {
        tabs
            .fullScreenCover(isPresented: Binding(
                get: { !onboardingComplete },
                set: { presented in onboardingComplete = !presented })
            ) {
                OnboardingView(engine: env.audioEngine) { onboardingComplete = true }
            }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            TodayView(coach: env.coach, tracker: env.tracker)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            StructuredPathView()
                .tabItem { Label("Path", systemImage: "map") }
                .tag(Tab.path)

            PracticeCoachView(coach: env.coach)
                .tabItem { Label("Practice", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.practice)

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
