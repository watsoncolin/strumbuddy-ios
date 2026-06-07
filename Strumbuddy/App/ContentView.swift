import SwiftUI

/// The three modes, one engine (design-doc §3).
struct ContentView: View {
    enum Tab: Hashable { case path, practice, freePlay }

    @State private var selection: Tab = .practice

    var body: some View {
        TabView(selection: $selection) {
            StructuredPathView()
                .tabItem { Label("Path", systemImage: "map") }
                .tag(Tab.path)

            PracticeCoachView()
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
