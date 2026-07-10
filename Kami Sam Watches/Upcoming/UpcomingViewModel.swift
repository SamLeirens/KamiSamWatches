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
        isLoading = true
        errorMessage = nil
        do {
            let ids = dataStore.trackedShows.map { $0.tmdbId }
            releases = try await service.fetchUpcomingReleases(showIds: ids)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
