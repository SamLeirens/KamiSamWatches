import Foundation
import Observation

@Observable
final class WatchNextViewModel {
    var episodes: [Episode] = []
    var isLoading = false
    var errorMessage: String?

    private let service: any EpisodeService
    private let dataStore: DataStore

    init(service: any EpisodeService = LiveEpisodeService(), dataStore: DataStore) {
        self.service = service
        self.dataStore = dataStore
    }

    func load() async {
        if episodes.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            let ids = dataStore.trackedShows.filter { !$0.hiddenFromWatchNext }.map { $0.tmdbId }
            var fetched = try await service.fetchNextEpisodes(showIds: ids, progress: dataStore.progressLookup)
            let lastWatched = dataStore.lastWatchedAt
            fetched.sort {
                switch (lastWatched[$0.tmdbShowId], lastWatched[$1.tmdbShowId]) {
                case (let a?, let b?): return a > b
                case (.some, .none): return true
                default: return false
                }
            }
            episodes = fetched
        } catch {
            if episodes.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func refresh() async {
        await TMDB.clearCache()
        await load()
    }

    func hideShow(tmdbId: Int) {
        dataStore.setHidden(tmdbId: tmdbId, hidden: true)
        episodes.removeAll { $0.tmdbShowId == tmdbId }
    }

    func markWatched(_ episode: Episode) async {
        if let i = episodes.firstIndex(where: { $0.id == episode.id }) {
            episodes[i].isWatched = true
        }
        dataStore.markWatched(episode: episode)
        let next = try? await service.fetchNextEpisode(
            showId: episode.tmdbShowId,
            progress: dataStore.progress(for: episode.tmdbShowId)
        )
        // Re-find the row — the array may have shifted during the await
        guard let currentIndex = episodes.firstIndex(where: { $0.id == episode.id }) else { return }
        if let next {
            episodes[currentIndex] = next
        } else {
            episodes.remove(at: currentIndex)
        }
        let lastWatched = dataStore.lastWatchedAt
        episodes.sort {
            switch (lastWatched[$0.tmdbShowId], lastWatched[$1.tmdbShowId]) {
            case (let a?, let b?): return a > b
            case (.some, .none): return true
            default: return false
            }
        }
    }
}
