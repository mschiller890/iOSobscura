import Foundation
import Observation
import ObscuraCore

@MainActor
@Observable
final class VersionLinksViewModel {
    let bundleID: String
    let version: String
    var state: LoadState<VersionDetail> = .idle

    private let client = ObscuraClient.shared

    init(bundleID: String, version: String) {
        self.bundleID = bundleID
        self.version = version
    }

    func load() async {
        state = .loading
        do {
            let detail = try await client.fetchVersionDetail(bundleID: bundleID, version: version)
            state = .loaded(detail)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
