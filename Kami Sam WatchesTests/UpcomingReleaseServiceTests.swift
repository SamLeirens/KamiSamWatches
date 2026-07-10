import XCTest
@testable import Kami_Sam_Watches

final class UpcomingReleaseServiceTests: XCTestCase {

    // MARK: - Shows with future next episode appear in results

    func testFutureEpisodeIsIncluded() async throws {
        let futureDate = dateString(daysFromNow: 3)
        let nextEp = TMDBEpisode.fixture(number: 2, season: 1, airDate: futureDate)
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, name: "Test Show", nextEpisode: nextEp)

        let service = LiveUpcomingReleaseService(tmdb: mock)
        let results = try await service.fetchUpcomingReleases(showIds: [1])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].showName, "Test Show")
    }

    // MARK: - Shows without next episode are excluded

    func testShowWithNoNextEpisodeIsExcluded() async throws {
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, nextEpisode: nil)

        let service = LiveUpcomingReleaseService(tmdb: mock)
        let results = try await service.fetchUpcomingReleases(showIds: [1])
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Past next_episode_to_air is excluded

    func testPastEpisodeIsExcluded() async throws {
        let pastDate = dateString(daysFromNow: -1)
        let nextEp = TMDBEpisode.fixture(number: 2, season: 1, airDate: pastDate)
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, nextEpisode: nextEp)

        let service = LiveUpcomingReleaseService(tmdb: mock)
        let results = try await service.fetchUpcomingReleases(showIds: [1])
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Episode 1 maps to seasonPremiere

    func testEpisodeOneBecomesSeasonPremiere() async throws {
        let futureDate = dateString(daysFromNow: 5)
        let nextEp = TMDBEpisode.fixture(number: 1, season: 2, airDate: futureDate)
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, nextEpisode: nextEp)

        let service = LiveUpcomingReleaseService(tmdb: mock)
        let results = try await service.fetchUpcomingReleases(showIds: [1])
        XCTAssertEqual(results.count, 1)
        if case .seasonPremiere(let s) = results[0].kind {
            XCTAssertEqual(s, 2)
        } else {
            XCTFail("Expected seasonPremiere, got \(results[0].kind)")
        }
    }

    // MARK: - Episode > 1 maps to episode kind

    func testNonFirstEpisodeMapsToEpisodeKind() async throws {
        let futureDate = dateString(daysFromNow: 5)
        let nextEp = TMDBEpisode.fixture(number: 4, season: 1, airDate: futureDate)
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, nextEpisode: nextEp)

        let service = LiveUpcomingReleaseService(tmdb: mock)
        let results = try await service.fetchUpcomingReleases(showIds: [1])
        if case .episode(let s, let e) = results[0].kind {
            XCTAssertEqual(s, 1)
            XCTAssertEqual(e, 4)
        } else {
            XCTFail("Expected episode kind, got \(results[0].kind)")
        }
    }

    // MARK: - Results are sorted by release date ascending

    func testResultsSortedByReleaseDate() async throws {
        let sooner = dateString(daysFromNow: 2)
        let later  = dateString(daysFromNow: 7)
        var mock = MockTMDBService()
        mock.showDetails[1] = .fixture(id: 1, name: "Soon",  nextEpisode: .fixture(number: 2, season: 1, airDate: sooner))
        mock.showDetails[2] = .fixture(id: 2, name: "Later", nextEpisode: .fixture(number: 2, season: 1, airDate: later))

        let service = LiveUpcomingReleaseService(tmdb: mock)
        let results = try await service.fetchUpcomingReleases(showIds: [2, 1])
        XCTAssertEqual(results.map { $0.showName }, ["Soon", "Later"])
    }

    // MARK: - Helpers

    private func dateString(daysFromNow days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
