import Foundation
@testable import Kami_Sam_Watches

// A configurable TMDB mock — tests set showDetails and seasonDetails before calling services.
struct MockTMDBService: TMDBService {
    var showDetails: [Int: TMDBShowDetail] = [:]
    var seasonDetails: [String: TMDBSeasonDetail] = [:]
    var searchResults: [TMDBSearchResult] = []
    var findResults: [Int: TMDBSearchResult] = [:]

    func fetchShowDetail(id: Int) async throws -> TMDBShowDetail {
        guard let detail = showDetails[id] else {
            throw URLError(.badServerResponse)
        }
        return detail
    }

    func fetchSeasonDetail(showId: Int, season: Int) async throws -> TMDBSeasonDetail {
        let key = "\(showId)-\(season)"
        guard let detail = seasonDetails[key] else {
            throw URLError(.badServerResponse)
        }
        return detail
    }

    func searchShows(query: String) async throws -> [TMDBSearchResult] {
        searchResults
    }

    func findShow(tvdbId: Int) async throws -> TMDBSearchResult? {
        findResults[tvdbId]
    }
}

// MARK: - Fixture helpers

extension TMDBEpisode {
    static func fixture(
        number: Int,
        season: Int = 1,
        name: String = "Episode",
        airDate: String? = nil,
        runtime: Int? = 45,
        stillPath: String? = nil
    ) -> TMDBEpisode {
        TMDBEpisode(
            episode_number: number,
            season_number: season,
            name: "\(name) \(number)",
            overview: nil,
            air_date: airDate,
            still_path: stillPath,
            runtime: runtime
        )
    }
}

extension TMDBShowDetail {
    static func fixture(
        id: Int = 1,
        name: String = "Test Show",
        seasons: [TMDBShowDetail.Season] = [.fixture()],
        nextEpisode: TMDBEpisode? = nil,
        lastEpisode: TMDBEpisode? = nil,
        backdropPath: String? = nil,
        posterPath: String? = nil,
        firstAirDate: String? = nil
    ) -> TMDBShowDetail {
        TMDBShowDetail(
            id: id,
            name: name,
            overview: nil,
            backdrop_path: backdropPath,
            poster_path: posterPath,
            first_air_date: firstAirDate,
            seasons: seasons,
            next_episode_to_air: nextEpisode,
            last_episode_to_air: lastEpisode
        )
    }
}

extension TMDBShowDetail.Season {
    static func fixture(number: Int = 1, episodeCount: Int = 6) -> TMDBShowDetail.Season {
        TMDBShowDetail.Season(
            season_number: number,
            name: "Season \(number)",
            episode_count: episodeCount,
            poster_path: nil,
            overview: nil
        )
    }
}

extension TMDBSeasonDetail {
    static func fixture(episodes: [TMDBEpisode]) -> TMDBSeasonDetail {
        TMDBSeasonDetail(poster_path: nil, episodes: episodes)
    }
}
