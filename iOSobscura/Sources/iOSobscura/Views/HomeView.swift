import SwiftUI
import ObscuraCore

/// The Browse tab: a native reconstruction of the website's homepage
/// ("Featured Apps" / "Some Apps" icon grids) with `.searchable` standing
/// in for the site's separate `/searchPost` search page - a native iOS
/// pattern for the same workflow, not a new feature.
struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    private let columns = [GridItem(.adaptive(minimum: 84, maximum: 110), spacing: 16)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Legacy iOS Apps")
                .searchable(text: $viewModel.searchText, prompt: "Search for an app")
                .onChange(of: viewModel.searchText) { _, _ in viewModel.searchTextChanged() }
                .task { await viewModel.loadHomeIfNeeded() }
                .navigationDestination(for: AppRoute.self) { route in
                    AppDetailView(bundleID: route.bundleID)
                }
                .navigationDestination(for: VersionRoute.self) { route in
                    VersionLinksView(bundleID: route.bundleID, version: route.version)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            homeContent
        } else {
            searchContent
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(message: "Loading apps…")
        case .failed(let message):
            ErrorStateView(message: message) { Task { await viewModel.loadHome() } }
        case .loaded(let sections):
            if sections.isEmpty {
                EmptyStateView(
                    systemImage: "square.grid.2x2",
                    title: "No Apps to Show",
                    message: "The server didn't return any featured apps."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.title)
                                    .font(.title3.bold())
                                    .padding(.horizontal)
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(section.apps) { app in
                                        NavigationLink(value: AppRoute(bundleID: app.bundleID)) {
                                            AppCardView(app: app)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable { await viewModel.loadHome() }
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        switch viewModel.searchState {
        case .idle:
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "Search iOS Obscura",
                message: "Find a legacy iOS app by name."
            )
        case .loading:
            LoadingStateView(message: "Searching…")
        case .failed(let message):
            ErrorStateView(message: message) { viewModel.retrySearch() }
        case .loaded(let apps):
            if apps.isEmpty {
                EmptyStateView(
                    systemImage: "questionmark.square.dashed",
                    title: "No Results",
                    message: "No apps matched \u{201C}\(viewModel.searchText)\u{201D}."
                )
            } else {
                List(apps) { app in
                    NavigationLink(value: AppRoute(bundleID: app.bundleID)) {
                        HStack(spacing: 12) {
                            ObscuraIconView(bundleID: app.bundleID, size: 44)
                            Text(app.cardTitle)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
