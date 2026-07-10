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
        isLoading = true
        errorMessage = nil
        do {
            let ids = dataStore.trackedShows.filter { !$0.hiddenFromWatchNext }.map { $0.tmdbId }
            episodes = try await service.fetchNextEpisodes(showIds: ids, progress: dataStore.progressLookup)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func hideShow(tmdbId: Int) async {
        dataStore.setHidden(tmdbId: tmdbId, hidden: true)
        await load()
    }

    func markWatched(_ episode: Episode) async {
        guard let index = episodes.firstIndex(where: { $0.id == episode.id }) else { return }
        episodes[index].isWatched = true
        dataStore.markWatched(episode: episode)
        await load()
    }
}
