import Foundation

protocol UpcomingReleaseService: Sendable {
    func fetchUpcomingReleases(showIds: [Int]) async throws -> [UpcomingRelease]
}

// MARK: - Live

struct LiveUpcomingReleaseService: UpcomingReleaseService {
    private let tmdb: any TMDBService

    init(tmdb: any TMDBService = TMDB.shared) {
        self.tmdb = tmdb
    }

    func fetchUpcomingReleases(showIds: [Int]) async throws -> [UpcomingRelease] {
        try await withThrowingTaskGroup(of: UpcomingRelease?.self) { group in
            for showId in showIds {
                group.addTask { try await fetchUpcoming(showId: showId) }
            }
            var results: [UpcomingRelease] = []
            for try await release in group {
                if let release { results.append(release) }
            }
            return results.sorted { $0.releaseDate < $1.releaseDate }
        }
    }

    // MARK: Private

    private func fetchUpcoming(showId: Int) async throws -> UpcomingRelease? {
        let show = try await tmdb.fetchShowDetail(id: showId)
        guard let next = show.next_episode_to_air,
              let dateStr = next.air_date,
              let airDate = TMDBFormat.parseDate(dateStr),
              airDate > .now
        else { return nil }

        let posterPath = show.poster_path
            ?? show.seasons.first(where: { $0.season_number == next.season_number })?.poster_path
        let posterURL = tmdb.imageURL(stillPath: posterPath)

        let kind: ReleaseKind = next.episode_number == 1
            ? .seasonPremiere(season: next.season_number)
            : .episode(season: next.season_number, episodeNumber: next.episode_number)

        return UpcomingRelease(
            tmdbShowId: showId,
            showName: show.name,
            title: next.name,
            kind: kind,
            overview: next.overview ?? "",
            releaseDate: airDate,
            posterURL: posterURL
        )
    }

}
