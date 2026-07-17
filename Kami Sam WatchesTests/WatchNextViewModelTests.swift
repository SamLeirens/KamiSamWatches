import XCTest
import SwiftData
@testable import Kami_Sam_Watches

@MainActor
final class WatchNextViewModelTests: XCTestCase {
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

    // MARK: - WatchNextFilter.matches

    func testFilterAllMatchesEverything() {
        XCTAssertTrue(WatchNextFilter.all.matches(makeEpisode(badge: nil)))
        XCTAssertTrue(WatchNextFilter.all.matches(makeEpisode(badge: .new)))
        XCTAssertTrue(WatchNextFilter.all.matches(makeEpisode(badge: .latest)))
        XCTAssertTrue(WatchNextFilter.all.matches(makeEpisode(badge: .premiere)))
    }

    func testFilterNewMatchesNewAndLatest() {
        XCTAssertTrue(WatchNextFilter.new.matches(makeEpisode(badge: .new)))
        XCTAssertTrue(WatchNextFilter.new.matches(makeEpisode(badge: .latest)))
    }

    func testFilterNewExcludesPremiereAndNoBadge() {
        XCTAssertFalse(WatchNextFilter.new.matches(makeEpisode(badge: .premiere)))
        XCTAssertFalse(WatchNextFilter.new.matches(makeEpisode(badge: nil)))
    }

    func testFilterPremieresMatchesPremiereOnly() {
        XCTAssertTrue(WatchNextFilter.premieres.matches(makeEpisode(badge: .premiere)))
    }

    func testFilterPremieresExcludesOthers() {
        XCTAssertFalse(WatchNextFilter.premieres.matches(makeEpisode(badge: .new)))
        XCTAssertFalse(WatchNextFilter.premieres.matches(makeEpisode(badge: .latest)))
        XCTAssertFalse(WatchNextFilter.premieres.matches(makeEpisode(badge: nil)))
    }

    // MARK: - filteredEpisodes

    func testFilteredEpisodesAllReturnsAll() {
        let vm = WatchNextViewModel(dataStore: store)
        vm.episodes = [makeEpisode(badge: nil), makeEpisode(badge: .new), makeEpisode(badge: .premiere)]
        vm.filter = .all
        XCTAssertEqual(vm.filteredEpisodes.count, 3)
    }

    func testFilteredEpisodesNewFilters() {
        let vm = WatchNextViewModel(dataStore: store)
        vm.episodes = [makeEpisode(badge: .new), makeEpisode(badge: .premiere), makeEpisode(badge: nil)]
        vm.filter = .new
        XCTAssertEqual(vm.filteredEpisodes.count, 1)
        XCTAssertEqual(vm.filteredEpisodes[0].badge, .new)
    }

    func testFilteredEpisodesPremieresFilters() {
        let vm = WatchNextViewModel(dataStore: store)
        vm.episodes = [makeEpisode(badge: .premiere), makeEpisode(badge: .new), makeEpisode(badge: .premiere)]
        vm.filter = .premieres
        XCTAssertEqual(vm.filteredEpisodes.count, 2)
    }

    // MARK: - Helpers

    private var episodeCounter = 0

    private func makeEpisode(badge: EpisodeBadge?) -> Episode {
        episodeCounter += 1
        return Episode(
            tmdbShowId: episodeCounter,
            showName: "Show \(episodeCounter)",
            title: "Episode",
            season: 1,
            episodeNumber: 1,
            durationMinutes: 45,
            seasonEpisodeCount: 10,
            thumbnailURL: nil,
            airDate: nil,
            badge: badge,
            isWatched: false
        )
    }
}
