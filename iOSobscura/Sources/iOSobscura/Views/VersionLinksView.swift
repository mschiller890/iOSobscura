import SwiftUI
import ObscuraCore

/// The native equivalent of `/getAppVersionLinks/{bundleID}/{version}`:
/// the iOS version requirement and every archived mirror for this release.
struct VersionLinksView: View {
    let bundleID: String
    let appName: String
    let version: String
    @State private var viewModel: VersionLinksViewModel

    init(bundleID: String, appName: String, version: String) {
        self.bundleID = bundleID
        self.appName = appName
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
                            DownloadLinkRow(link: link, bundleID: bundleID, appName: appName, version: version)
                        }
                    } header: {
                        Text("\(detail.links.count) Mirror\(detail.links.count == 1 ? "" : "s")")
                    } footer: {
                        Text("Files are hosted by third parties (such as archive.org), not by this app. Downloads continue in the background and appear on the Downloads tab; iOS does not install .ipa files directly, so use a sideloading tool you trust to install one.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
