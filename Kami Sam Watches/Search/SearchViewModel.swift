import Foundation
import Observation

@Observable
final class SearchViewModel {
    var query = ""
    var results: [TMDBSearchResult] = []
    var isLoading = false
    var errorMessage: String?

    private let tmdb: any TMDBService
    private let dataStore: DataStore
    private var searchTask: Task<Void, Never>?

    init(tmdb: any TMDBService = TMDB.shared, dataStore: DataStore) {
        self.tmdb = tmdb
        self.dataStore = dataStore
    }

    func search() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }

        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            isLoading = true
            errorMessage = nil
            do {
                results = try await tmdb.searchShows(query: q)
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }

    func isTracking(_ show: TMDBSearchResult) -> Bool {
        dataStore.trackedShows.contains(where: { $0.tmdbId == show.id })
    }

    func toggleTracking(_ show: TMDBSearchResult) {
        if let existing = dataStore.trackedShows.first(where: { $0.tmdbId == show.id }) {
            dataStore.removeShow(existing)
        } else {
            dataStore.addShow(tmdbId: show.id, showName: show.name)
        }
    }
}
