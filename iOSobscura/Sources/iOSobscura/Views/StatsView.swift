import SwiftUI
import ObscuraCore

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private func formatted(_ count: Int?) -> String {
    guard let count else { return "—" }
    return count.formatted(.number)
}

private func formatted(_ flag: Bool?) -> String {
    guard let flag else { return "—" }
    return flag ? "Yes" : "No"
}

/// The native equivalent of `/stats`.
struct StatsView: View {
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Server Stats")
                .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(message: "Loading stats…")
        case .failed(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let stats):
            List {
                Section("Server") {
                    StatRow(label: "App Count", value: formatted(stats.appCount))
                    StatRow(label: "Version Count", value: formatted(stats.versionCount))
                    StatRow(label: "URL Count", value: formatted(stats.urlCount))
                }
                Section {
                    StatRow(label: "iOS Device?", value: formatted(stats.isIOSDevice))
                    StatRow(label: "macOS Device?", value: formatted(stats.isMacDevice))
                    StatRow(label: "Searchable App Count", value: formatted(stats.searchableAppCount))
                    StatRow(label: "Searchable Version Count", value: formatted(stats.searchableVersionCount))
                    StatRow(label: "Searchable URL Count", value: formatted(stats.searchableURLCount))
                } header: {
                    Text("Your Device")
                } footer: {
                    Text("As reported by the server for this request, exactly as the website's own Stats page shows it.")
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await viewModel.load() }
        }
    }
}
