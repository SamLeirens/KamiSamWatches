import XCTest
@testable import Kami_Sam_Watches

final class RecommendationServiceTests: XCTestCase {

    private func seed(_ id: Int, _ name: String) -> RecommendationSeed {
        RecommendationSeed(id: id, name: name)
    }

    func testShowRecommendedByMultipleSeedsRanksFirst() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: [.fixture(id: 101), .fixture(id: 100)],
            2: [.fixture(id: 100)],
            3: [.fixture(id: 102)],
        ]
        let service = LiveRecommendationService(tmdb: mock)

        let recs = try await service.recommendations(
            for: [seed(1, "Severance"), seed(2, "Dark"), seed(3, "Fargo")],
            excluding: []
        )

        XCTAssertEqual(recs.first?.id, 100)
        XCTAssertEqual(recs.first?.sourceShowNames, ["Severance", "Dark"])
        XCTAssertEqual(recs.first?.reasonText, "Because you watch Severance and Dark")
    }

    func testExcludesTrackedShowsAndSeeds() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: [.fixture(id: 100), .fixture(id: 2), .fixture(id: 103)],
            2: [.fixture(id: 1)],
        ]
        let service = LiveRecommendationService(tmdb: mock)

        let recs = try await service.recommendations(
            for: [seed(1, "A"), seed(2, "B")],
            excluding: [100]
        )

        XCTAssertEqual(recs.map(\.id), [103])
    }

    func testSharedGenresResolvedFromSeedDetails() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: [.fixture(id: 100, genreIds: [18, 9999])],
        ]
        mock.showDetails = [
            1: .fixture(id: 1, genres: [TMDBGenre(id: 18, name: "Drama"), TMDBGenre(id: 80, name: "Crime")]),
        ]
        let service = LiveRecommendationService(tmdb: mock)

        let recs = try await service.recommendations(for: [seed(1, "A")], excluding: [])

        XCTAssertEqual(recs.first?.sharedGenres, ["Drama"])
    }

    func testRelevancePositionBreaksTiesBeforeVote() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: [.fixture(id: 100, vote: 5.0), .fixture(id: 101, vote: 9.0)],
        ]
        let service = LiveRecommendationService(tmdb: mock)

        let recs = try await service.recommendations(for: [seed(1, "A")], excluding: [])

        XCTAssertEqual(recs.map(\.id), [100, 101])
    }

    func testVoteAverageBreaksEqualPositionTies() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: [.fixture(id: 100, vote: 5.0)],
            2: [.fixture(id: 101, vote: 9.0)],
        ]
        let service = LiveRecommendationService(tmdb: mock)

        let recs = try await service.recommendations(for: [seed(1, "A"), seed(2, "B")], excluding: [])

        XCTAssertEqual(recs.map(\.id), [101, 100])
    }

    func testPartialSeedFailureStillReturnsResults() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: [.fixture(id: 100)],
            // seed 2 has no entry — its fetch throws
        ]
        let service = LiveRecommendationService(tmdb: mock)

        let recs = try await service.recommendations(for: [seed(1, "A"), seed(2, "B")], excluding: [])

        XCTAssertEqual(recs.map(\.id), [100])
        XCTAssertEqual(recs.first?.sourceShowNames, ["A"])
    }

    func testAllSeedsFailingThrows() async {
        let service = LiveRecommendationService(tmdb: MockTMDBService())

        do {
            _ = try await service.recommendations(for: [seed(1, "A"), seed(2, "B")], excluding: [])
            XCTFail("Expected an error when every seed fetch fails")
        } catch {
            // expected
        }
    }

    func testResultsCappedAtMaxResults() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: (100...110).map { .fixture(id: $0) },
        ]
        let service = LiveRecommendationService(tmdb: mock, maxResults: 3)

        let recs = try await service.recommendations(for: [seed(1, "A")], excluding: [])

        XCTAssertEqual(recs.count, 3)
    }

    func testThreeSourceReasonUsesListFormatting() async throws {
        var mock = MockTMDBService()
        mock.recommendations = [
            1: [.fixture(id: 100)],
            2: [.fixture(id: 100)],
            3: [.fixture(id: 100)],
        ]
        let service = LiveRecommendationService(tmdb: mock)

        let recs = try await service.recommendations(for: [seed(1, "A"), seed(2, "B"), seed(3, "C")], excluding: [])

        XCTAssertEqual(recs.first?.reasonText, "Because you watch A, B, and C")
    }
}
