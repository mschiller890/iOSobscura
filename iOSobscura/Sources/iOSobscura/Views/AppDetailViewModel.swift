import Foundation
import Observation
import ObscuraCore

@MainActor
@Observable
final class AppDetailViewModel {
    let bundleID: String
    var state: LoadState<AppDetail> = .idle

    private let client = ObscuraClient.shared

    init(bundleID: String) {
        self.bundleID = bundleID
    }

    func load() async {
        state = .loading
        do {
            let detail = try await client.fetchAppDetail(bundleID: bundleID)
            state = .loaded(detail)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
