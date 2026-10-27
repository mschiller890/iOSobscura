import SwiftUI
import ObscuraCore

/// The native equivalent of `/getAppVersions/{bundleID}`: the app's name,
/// developer and the full list of archived versions, each pushing to that
/// version's download links.
struct AppDetailView: View {
    let bundleID: String
    @State private var viewModel: AppDetailViewModel

    init(bundleID: String) {
        self.bundleID = bundleID
        _viewModel = State(initialValue: AppDetailViewModel(bundleID: bundleID))
    }

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .task(id: bundleID) { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(message: "Loading app…")
        case .failed(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let detail):
            List {
                Section {
                    HStack(spacing: 16) {
                        ObscuraIconView(bundleID: bundleID, size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.name)
                                .font(.headline)
                            if let developer = detail.developer {
                                Text(developer)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }

                if detail.versions.isEmpty {
                    Section {
                        EmptyStateView(
                            systemImage: "clock.arrow.circlepath",
                            title: "No Versions Found",
                            message: "iOS Obscura doesn't have any archived versions of this app."
                        )
                        .listRowInsets(EdgeInsets())
                    }
                } else {
                    Section("\(detail.versions.count) Version\(detail.versions.count == 1 ? "" : "s")") {
                        ForEach(detail.versions) { version in
                            NavigationLink(value: VersionRoute(bundleID: bundleID, version: version.version)) {
                                Text(version.version)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
