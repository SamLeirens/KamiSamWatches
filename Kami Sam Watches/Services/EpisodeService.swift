import Foundation

protocol EpisodeService: Sendable {
    func fetchNextEpisodes(
        showIds: [Int],
        progress: [Int: (season: Int, episode: Int)]
    ) async throws -> [Episode]

    func fetchNextEpisode(
        showId: Int,
        progress: (season: Int, episode: Int)?
    ) async throws -> Episode?
}

// MARK: - Live

struct LiveEpisodeService: EpisodeService {
    private let tmdb: any TMDBService

    init(tmdb: any TMDBService = TMDB.shared) {
        self.tmdb = tmdb
    }

    func fetchNextEpisodes(
        showIds: [Int],
        progress: [Int: (season: Int, episode: Int)]
    ) async throws -> [Episode] {
        try await withThrowingTaskGroup(of: (Int, Episode?).self) { group in
            for (index, showId) in showIds.enumerated() {
                group.addTask { (index, try await fetchNext(showId: showId, progress: progress[showId])) }
            }
            var results: [(Int, Episode)] = []
            for try await (i, ep) in group {
                if let ep { results.append((i, ep)) }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    func fetchNextEpisode(
        showId: Int,
        progress: (season: Int, episode: Int)?
    ) async throws -> Episode? {
        try await fetchNext(showId: showId, progress: progress)
    }

    // MARK: Private

    private func fetchNext(showId: Int, progress: (season: Int, episode: Int)?) async throws -> Episode? {
        let show = try await tmdb.fetchShowDetail(id: showId)
        guard let (ep, season) = await resolveNextEpisode(showId: showId, show: show, progress: progress) else { return nil }
        let imageURL = tmdb.imageURL(stillPath: ep.still_path) ?? tmdb.imageURL(stillPath: season.poster_path)
        let airDate = ep.air_date.flatMap { try? Date($0, strategy: Self.dateStrategy) }
        if let airDate, airDate > .now { return nil }
        return Episode(
            tmdbShowId: showId,
            showName: show.name,
            title: ep.name,
            season: ep.season_number,
            episodeNumber: ep.episode_number,
            durationMinutes: ep.runtime ?? 0,
            seasonEpisodeCount: season.episodes.count,
            thumbnailURL: imageURL,
            airDate: airDate,
            badge: badge(for: ep, show: show),
            isWatched: false
        )
    }

    private func resolveNextEpisode(
        showId: Int,
        show: TMDBShowDetail,
        progress: (season: Int, episode: Int)?
    ) async -> (TMDBEpisode, TMDBSeasonDetail)? {
        let (candidateSeason, candidateEpisode): (Int, Int)

        if let p = progress {
            candidateSeason = p.season
            candidateEpisode = p.episode + 1
        } else {
            let first = show.seasons.filter { $0.season_number > 0 }.min(by: { $0.season_number < $1.season_number })
            candidateSeason = first?.season_number ?? 1
            candidateEpisode = 1
        }

        if let result = await episodeInSeason(showId: showId, season: candidateSeason, episodeNumber: candidateEpisode) {
            return result
        }

        // Season exhausted — advance to the next available season
        let nextSeason = show.seasons
            .filter { $0.season_number > candidateSeason }
            .min(by: { $0.season_number < $1.season_number })?.season_number
        guard let nextSeason else { return nil }
        return await episodeInSeason(showId: showId, season: nextSeason, episodeNumber: 1)
    }

    private func episodeInSeason(showId: Int, season: Int, episodeNumber: Int) async -> (TMDBEpisode, TMDBSeasonDetail)? {
        guard let detail = try? await tmdb.fetchSeasonDetail(showId: showId, season: season),
              let ep = detail.episodes.first(where: { $0.episode_number == episodeNumber })
        else { return nil }
        return (ep, detail)
    }

    private func badge(for ep: TMDBEpisode, show: TMDBShowDetail) -> EpisodeBadge? {
        if ep.episode_number == 1 { return .premiere }
        if let last = show.last_episode_to_air,
           last.season_number == ep.season_number,
           last.episode_number == ep.episode_number { return .latest }
        if let dateStr = ep.air_date,
           let airDate = try? Date(dateStr, strategy: Self.dateStrategy),
           Calendar.current.dateComponents([.day], from: airDate, to: .now).day.map({ $0 <= 14 }) == true {
            return .new
        }
        return nil
    }

    private static let dateStrategy = Date.ParseStrategy(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt
    )
}
