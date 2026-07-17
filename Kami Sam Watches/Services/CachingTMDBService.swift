import Foundation

struct CachingTMDBService: TMDBService {
    private let base: any TMDBService
    private let cache: TMDBCache

    private enum TTL {
        static let showDetail: TimeInterval = 30 * 60
        static let seasonDetail: TimeInterval = 24 * 3600
        static let findShow: TimeInterval = 24 * 3600
        static let recommendations: TimeInterval = 30 * 60
    }

    init(base: any TMDBService, cache: TMDBCache) {
        self.base = base
        self.cache = cache
    }

    func fetchShowDetail(id: Int) async throws -> TMDBShowDetail {
        let key = "show-\(id)"
        if let cached: TMDBShowDetail = await cache.get(key: key) { return cached }
        let value = try await base.fetchShowDetail(id: id)
        await cache.set(value, key: key, ttl: TTL.showDetail)
        return value
    }

    func fetchSeasonDetail(showId: Int, season: Int) async throws -> TMDBSeasonDetail {
        let key = "season-\(showId)-\(season)"
        if let cached: TMDBSeasonDetail = await cache.get(key: key) { return cached }
        let value = try await base.fetchSeasonDetail(showId: showId, season: season)
        await cache.set(value, key: key, ttl: TTL.seasonDetail)
        return value
    }

    func searchShows(query: String) async throws -> [TMDBSearchResult] {
        try await base.searchShows(query: query)
    }

    func findShow(tvdbId: Int) async throws -> TMDBSearchResult? {
        let key = "find-\(tvdbId)"
        if let cached: TMDBSearchResult = await cache.get(key: key) { return cached }
        guard let value = try await base.findShow(tvdbId: tvdbId) else { return nil }
        await cache.set(value, key: key, ttl: TTL.findShow)
        return value
    }

    func fetchRecommendations(showId: Int) async throws -> [TMDBRecommendedShow] {
        let key = "recommendations-\(showId)"
        if let cached: [TMDBRecommendedShow] = await cache.get(key: key) { return cached }
        let value = try await base.fetchRecommendations(showId: showId)
        await cache.set(value, key: key, ttl: TTL.recommendations)
        return value
    }
}
