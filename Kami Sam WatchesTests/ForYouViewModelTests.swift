import XCTest
import SwiftData
@testable import Kami_Sam_Watches

@MainActor
final class ForYouViewModelTests: XCTestCase {
    var store: Kami_Sam_Watches.DataStore!
    var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: TrackedShow.self, WatchEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = Kami_Sam_Watches.DataStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
    }

    // MARK: - Seed selection

    func testToggleSeedSelectsAndDeselects() {
        let vm = makeViewModel()
        let seed = RecommendationSeed(id: 1, name: "Severance")

        vm.toggleSeed(seed)
        XCTAssertTrue(vm.isSelected(1))

        vm.toggleSeed(seed)
        XCTAssertFalse(vm.isSelected(1))
    }

    func testSelectionCappedAtMaxSeeds() {
        let vm = makeViewModel()
        for id in 1...6 {
            vm.toggleSeed(RecommendationSeed(id: id, name: "Show \(id)"))
        }

        XCTAssertEqual(vm.selectedSeeds.count, ForYouViewModel.maxSeeds)
        XCTAssertFalse(vm.isSelected(6))
        XCTAssertFalse(vm.canSelectMore)
    }

    func testCanRecommendRequiresThreeToFiveSeeds() {
        let vm = makeViewModel()

        vm.toggleSeed(RecommendationSeed(id: 1, name: "A"))
        vm.toggleSeed(RecommendationSeed(id: 2, name: "B"))
        XCTAssertFalse(vm.canRecommend)

        vm.toggleSeed(RecommendationSeed(id: 3, name: "C"))
        XCTAssertTrue(vm.canRecommend)

        vm.toggleSeed(RecommendationSeed(id: 4, name: "D"))
        vm.toggleSeed(RecommendationSeed(id: 5, name: "E"))
        XCTAssertTrue(vm.canRecommend)
    }

    func testExtraSelectedSeedsOmitsTrackedShows() {
        store.addShow(tmdbId: 1, showName: "Tracked")
        let vm = makeViewModel()

        vm.toggleSeed(RecommendationSeed(id: 1, name: "Tracked"))
        vm.toggleSeed(RecommendationSeed(id: 2, name: "Searched"))

        XCTAssertEqual(vm.extraSelectedSeeds.map(\.id), [2])
    }

    // MARK: - Recommendations

    func testGetRecommendationsPopulatesResultsAndSwitchesStage() async {
        let expected = [makeRecommendation(id: 100)]
        let vm = makeViewModel(service: MockRecommendationService(handler: { _, _ in expected }))
        selectSeeds(vm, count: 3)

        await vm.getRecommendations()

        XCTAssertEqual(vm.stage, .results)
        XCTAssertEqual(vm.recommendations.map(\.id), [100])
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func testGetRecommendationsPassesTrackedIdsToService() async {
        store.addShow(tmdbId: 42, showName: "Tracked")
        let vm = makeViewModel(service: MockRecommendationService(handler: { _, trackedIds in
            XCTAssertEqual(trackedIds, [42])
            return []
        }))
        selectSeeds(vm, count: 3)

        await vm.getRecommendations()
    }

    func testGetRecommendationsErrorSetsMessage() async {
        let vm = makeViewModel(service: MockRecommendationService(handler: { _, _ in
            throw URLError(.notConnectedToInternet)
        }))
        selectSeeds(vm, count: 3)

        await vm.getRecommendations()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.recommendations.isEmpty)
    }

    func testGetRecommendationsIgnoredBelowMinimumSeeds() async {
        let vm = makeViewModel(service: MockRecommendationService(handler: { _, _ in
            XCTFail("Service should not be called with too few seeds")
            return []
        }))
        selectSeeds(vm, count: 2)

        await vm.getRecommendations()

        XCTAssertEqual(vm.stage, .picking)
    }

    // MARK: - Tracking

    func testToggleTrackingAddsAndRemovesShow() {
        let vm = makeViewModel()
        let recommendation = makeRecommendation(id: 100)

        vm.toggleTracking(recommendation)
        XCTAssertTrue(vm.isTracking(100))

        vm.toggleTracking(recommendation)
        XCTAssertFalse(vm.isTracking(100))
    }

    // MARK: - Helpers

    private struct MockRecommendationService: RecommendationService {
        let handler: @Sendable ([RecommendationSeed], Set<Int>) throws -> [ShowRecommendation]

        func recommendations(for seeds: [RecommendationSeed], excluding trackedIds: Set<Int>) async throws -> [ShowRecommendation] {
            try handler(seeds, trackedIds)
        }
    }

    private func makeViewModel(service: any RecommendationService = MockRecommendationService(handler: { _, _ in [] })) -> ForYouViewModel {
        ForYouViewModel(service: service, tmdb: MockTMDBService(), dataStore: store)
    }

    private func selectSeeds(_ vm: ForYouViewModel, count: Int) {
        for id in 1...count {
            vm.toggleSeed(RecommendationSeed(id: id, name: "Seed \(id)"))
        }
    }

    private func makeRecommendation(id: Int) -> ShowRecommendation {
        ShowRecommendation(
            id: id,
            name: "Show \(id)",
            overview: nil,
            posterURL: nil,
            firstAirYear: nil,
            voteAverage: nil,
            sourceShowNames: ["Seed 1"],
            sharedGenres: []
        )
    }
}
