import Foundation
import Observation
import ObscuraCore

@MainActor
@Observable
final class HomeViewModel {
    var state: LoadState<[ObscuraAppSection]> = .idle
    var searchText = ""
    var searchState: LoadState<[ObscuraApp]> = .idle

    private let client = ObscuraClient.shared
    private var searchTask: Task<Void, Never>?

    func loadHomeIfNeeded() async {
        if case .loaded = state { return }
        await loadHome()
    }

    func loadHome() async {
        state = .loading
        do {
            let sections = try await client.fetchHome()
            state = .loaded(sections)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Debounces by 300ms so a fast typist doesn't fire one request per
    /// keystroke; cancelling the in-flight task on every change is what
    /// makes that safe to do from `onChange` without a request backlog.
    func searchTextChanged() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchState = .idle
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self.performSearch(query: query)
        }
    }

    func retrySearch() {
        searchTextChanged()
    }

    private func performSearch(query: String) async {
        searchState = .loading
        do {
            let apps = try await client.search(query: query)
            guard !Task.isCancelled else { return }
            searchState = .loaded(apps)
        } catch {
            guard !Task.isCancelled else { return }
            searchState = .failed(error.localizedDescription)
        }
    }
}
