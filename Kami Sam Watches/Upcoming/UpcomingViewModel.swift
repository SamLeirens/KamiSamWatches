import Foundation
import Observation

@Observable
final class UpcomingViewModel {
    var releases: [UpcomingRelease] = []
    var isLoading = false
    var errorMessage: String?

    private let service: any UpcomingReleaseService
    private let dataStore: DataStore

    init(service: any UpcomingReleaseService = LiveUpcomingReleaseService(), dataStore: DataStore) {
        self.service = service
        self.dataStore = dataStore
    }

    func load() async {
        if releases.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            let ids = dataStore.trackedShows.map { $0.tmdbId }
            releases = try await service.fetchUpcomingReleases(showIds: ids)
        } catch {
            if releases.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func refresh() async {
        await TMDB.clearCache()
        await load()
    }
}
