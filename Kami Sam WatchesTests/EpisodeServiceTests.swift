import XCTest
@testable import Kami_Sam_Watches

final class EpisodeServiceTests: XCTestCase {

    // MARK: - No progress → first episode of first main season

    func testFirstEpisodeReturnedWhenNoProgress() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [1], progress: [:])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].episodeNumber, 1)
        XCTAssertEqual(results[0].season, 1)
    }

    // MARK: - With progress → next episode in same season

    func testNextEpisodeReturnedWithProgress() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1),
            .fixture(number: 3, season: 1),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(
            showIds: [1], progress: [1: (season: 1, episode: 2)]
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].episodeNumber, 3)
    }

    // MARK: - Season boundary → advances to first episode of next season

    func testAdvancesToNextSeasonWhenCurrentExhausted() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(
            id: 1,
            seasons: [.fixture(number: 1, episodeCount: 3), .fixture(number: 2, episodeCount: 6)]
        )
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1),
            .fixture(number: 3, season: 1),
        ])
        mock.seasonDetails["1-2"] = .fixture(episodes: [
            .fixture(number: 1, season: 2),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        // Progress = watched episode 3 of season 1
        let results = try await service.fetchNextEpisodes(
            showIds: [1], progress: [1: (season: 1, episode: 3)]
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].season, 2)
        XCTAssertEqual(results[0].episodeNumber, 1)
    }

    // MARK: - Show complete (last season also exhausted) → excluded from results

    func testShowCompleteReturnsNoResult() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1, episodeCount: 2)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        // Progress = watched last episode of last season
        let results = try await service.fetchNextEpisodes(
            showIds: [1], progress: [1: (season: 1, episode: 2)]
        )
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Season 0 (specials) is skipped; main seasons start at 1

    func testSeasonZeroIsSkipped() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(
            id: 1,
            seasons: [
                TMDBShowDetail.Season(season_number: 0, name: "Specials", episode_count: 3, poster_path: nil, overview: nil),
                .fixture(number: 1),
            ]
        )
        mock.seasonDetails["1-1"] = .fixture(episodes: [.fixture(number: 1, season: 1)])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [1], progress: [:])
        XCTAssertEqual(results[0].season, 1)
        XCTAssertEqual(results[0].episodeNumber, 1)
    }

    // MARK: - Badge assignment

    func testPremiereBadgeOnEpisodeOne() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [.fixture(number: 1, season: 1)])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [1], progress: [:])
        XCTAssertEqual(results[0].badge, .premiere)
    }

    func testLatestBadgeWhenMatchingLastAiredEpisode() async throws {
        let lastEp = TMDBEpisode.fixture(number: 3, season: 1)
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)], lastEpisode: lastEp)
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1),
            .fixture(number: 3, season: 1),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(
            showIds: [1], progress: [1: (season: 1, episode: 2)]
        )
        XCTAssertEqual(results[0].badge, .latest)
    }

    func testNewBadgeForRecentlyAiredEpisode() async throws {
        let recentDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 86400))
            .prefix(10)
        let airDate = String(recentDate)
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1, airDate: airDate),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(
            showIds: [1], progress: [1: (season: 1, episode: 1)]
        )
        XCTAssertEqual(results[0].badge, .new)
    }

    func testNoBadgeForOldEpisode() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1, airDate: "2020-01-01"),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(
            showIds: [1], progress: [1: (season: 1, episode: 1)]
        )
        XCTAssertNil(results[0].badge)
    }

    // MARK: - Unaired episode filtering

    func testUnairedEpisodeIsExcludedFromWatchNext() async throws {
        let futureDate = String(ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 86400)).prefix(10))
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1, airDate: futureDate),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [1], progress: [:])
        XCTAssertEqual(results.count, 0)
    }

    func testAiredEpisodeIsIncluded() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1, airDate: "2020-01-01"),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [1], progress: [:])
        XCTAssertEqual(results.count, 1)
    }

    func testEpisodeWithNoAirDateIsIncluded() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1, airDate: nil),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [1], progress: [:])
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - seasonEpisodeCount is populated

    func testSeasonEpisodeCountMatchesActualEpisodes() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, seasons: [.fixture(number: 1)])
        mock.seasonDetails["1-1"] = .fixture(episodes: [
            .fixture(number: 1, season: 1),
            .fixture(number: 2, season: 1),
            .fixture(number: 3, season: 1),
        ])
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [1], progress: [:])
        XCTAssertEqual(results[0].seasonEpisodeCount, 3)
    }

    // MARK: - Multiple shows maintain order

    func testMultipleShowsReturnedInInputOrder() async throws {
        var mock = MockTMDBService()
        for id in [10, 20, 30] {
            mock.showDetails[id] = .fixture(id: id, name: "Show \(id)", seasons: [.fixture(number: 1)])
            mock.seasonDetails["\(id)-1"] = .fixture(episodes: [.fixture(number: 1, season: 1)])
        }
        let service = LiveEpisodeService(tmdb: mock)
        let results = try await service.fetchNextEpisodes(showIds: [10, 20, 30], progress: [:])
        XCTAssertEqual(results.map { $0.tmdbShowId }, [10, 20, 30])
    }
}
