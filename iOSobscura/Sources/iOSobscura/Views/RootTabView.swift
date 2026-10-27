import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}
