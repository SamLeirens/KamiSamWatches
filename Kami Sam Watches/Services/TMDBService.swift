import Foundation

// MARK: - Response models

struct TMDBEpisode: Decodable, Sendable {
    let episode_number: Int
    let season_number: Int
    let name: String
    let overview: String?
    let air_date: String?
    let still_path: String?
    let runtime: Int?
}

struct TMDBShowDetail: Decodable, Sendable {
    struct Season: Decodable, Sendable {
        let season_number: Int
        let name: String?
        let episode_count: Int?
        let poster_path: String?
        let overview: String?
    }
    let id: Int
    let name: String
    let overview: String?
    let seasons: [Season]
    let next_episode_to_air: TMDBEpisode?
    let last_episode_to_air: TMDBEpisode?
}

struct TMDBSeasonDetail: Decodable, Sendable {
    let poster_path: String?
    let episodes: [TMDBEpisode]
}

struct TMDBSearchResult: Decodable, Sendable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let first_air_date: String?
    let poster_path: String?
    let vote_average: Double?

    var firstAirYear: String? {
        first_air_date.flatMap { $0.split(separator: "-").first.map(String.init) }
    }
}

// MARK: - Protocol

protocol TMDBService: Sendable {
    func fetchShowDetail(id: Int) async throws -> TMDBShowDetail
    func fetchSeasonDetail(showId: Int, season: Int) async throws -> TMDBSeasonDetail
    func searchShows(query: String) async throws -> [TMDBSearchResult]
    func findShow(tvdbId: Int) async throws -> TMDBSearchResult?
}

extension TMDBService {
    static var imageBase: String { "https://image.tmdb.org/t/p/w300" }

    func imageURL(stillPath: String?) -> URL? {
        stillPath.flatMap { URL(string: Self.imageBase + $0) }
    }
}

// MARK: - Live

struct LiveTMDBService: TMDBService {
    func fetchShowDetail(id: Int) async throws -> TMDBShowDetail {
        let url = URL(string: "https://api.themoviedb.org/3/tv/\(id)")!
        return try JSONDecoder().decode(TMDBShowDetail.self, from: try await fetch(url))
    }

    func fetchSeasonDetail(showId: Int, season: Int) async throws -> TMDBSeasonDetail {
        let url = URL(string: "https://api.themoviedb.org/3/tv/\(showId)/season/\(season)")!
        return try JSONDecoder().decode(TMDBSeasonDetail.self, from: try await fetch(url))
    }

    func searchShows(query: String) async throws -> [TMDBSearchResult] {
        var components = URLComponents(string: "https://api.themoviedb.org/3/search/tv")!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        let url = components.url!
        struct Response: Decodable { let results: [TMDBSearchResult] }
        return try JSONDecoder().decode(Response.self, from: try await fetch(url)).results
    }

    func findShow(tvdbId: Int) async throws -> TMDBSearchResult? {
        var components = URLComponents(string: "https://api.themoviedb.org/3/find/\(tvdbId)")!
        components.queryItems = [URLQueryItem(name: "external_source", value: "tvdb_id")]
        let url = components.url!
        struct Response: Decodable { let tv_results: [TMDBSearchResult] }
        return try JSONDecoder().decode(Response.self, from: try await fetch(url)).tv_results.first
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Secrets.tmdbBearerToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
