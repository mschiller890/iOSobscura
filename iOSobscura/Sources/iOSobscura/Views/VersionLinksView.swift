import SwiftUI
import ObscuraCore

/// The native equivalent of `/getAppVersionLinks/{bundleID}/{version}`:
/// the iOS version requirement and every archived mirror for this release.
struct VersionLinksView: View {
    let bundleID: String
    let version: String
    @State private var viewModel: VersionLinksViewModel

    init(bundleID: String, version: String) {
        self.bundleID = bundleID
        self.version = version
        _viewModel = State(initialValue: VersionLinksViewModel(bundleID: bundleID, version: version))
    }

    var body: some View {
        content
            .navigationTitle(version)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(bundleID)/\(version)") { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(message: "Loading download links…")
        case .failed(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let detail):
            if detail.links.isEmpty {
                EmptyStateView(
                    systemImage: "exclamationmark.icloud",
                    title: "No Download Links",
                    message: "iOS Obscura doesn't have any mirrors for this version."
                )
            } else {
                List {
                    Section {
                        HStack {
                            Text("Version \(version)")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if let requiresIOS = detail.requiresIOS {
                                Text("Requires iOS \(requiresIOS)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        ForEach(detail.links) { link in
                            DownloadLinkRow(link: link)
                        }
                    } header: {
                        Text("\(detail.links.count) Mirror\(detail.links.count == 1 ? "" : "s")")
                    } footer: {
                        Text("Files are hosted by third parties (such as archive.org), not by this app. iOS does not install .ipa files directly - use a sideloading tool you trust.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
