import Foundation
import Observation
import ObscuraCore

@MainActor
@Observable
final class StatsViewModel {
    var state: LoadState<ServerStats> = .idle

    private let client = ObscuraClient.shared

    func load() async {
        state = .loading
        do {
            let stats = try await client.fetchStats()
            state = .loaded(stats)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
