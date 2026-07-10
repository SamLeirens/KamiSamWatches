import XCTest
import SwiftData
@testable import Kami_Sam_Watches

@MainActor
final class DataStoreTests: XCTestCase {
    var store: Kami_Sam_Watches.DataStore!
    var container: ModelContainer!  // retained so ModelContext stays alive

    override func setUp() async throws {
        container = try ModelContainer(
            for: TrackedShow.self, WatchEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = Kami_Sam_Watches.DataStore(modelContext: container.mainContext)
        // Remove seed shows so each test starts clean
        let seeds = store.trackedShows
        for show in seeds { store.removeShow(show) }
    }

    override func tearDown() async throws {
        store = nil
        container = nil
    }

    // MARK: - Show tracking

    func testAddShowAppearsInTrackedShows() async {
        store.addShow(tmdbId: 42, showName: "Test Show")
        XCTAssertEqual(store.trackedShows.count, 1)
        XCTAssertEqual(store.trackedShows[0].tmdbId, 42)
    }

    func testAddShowDuplicateIsIgnored() async {
        store.addShow(tmdbId: 42, showName: "Test Show")
        store.addShow(tmdbId: 42, showName: "Test Show")
        XCTAssertEqual(store.trackedShows.count, 1)
    }

    func testRemoveShowRemovesFromTrackedShows() async {
        store.addShow(tmdbId: 42, showName: "Test Show")
        let show = store.trackedShows[0]
        store.removeShow(show)
        XCTAssertTrue(store.trackedShows.isEmpty)
    }

    // MARK: - Watch state

    func testIsWatchedReturnsFalseInitially() async {
        XCTAssertFalse(store.isWatched(showId: 1, season: 1, episode: 1))
    }

    func testToggleWatchedMarksEpisodeWatched() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 45)
        XCTAssertTrue(store.isWatched(showId: 1, season: 1, episode: 1))
    }

    func testToggleWatchedTwiceUndoes() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 45)
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 45)
        XCTAssertFalse(store.isWatched(showId: 1, season: 1, episode: 1))
    }

    func testIsWatchedIsolatedToCorrectEpisode() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 45)
        XCTAssertFalse(store.isWatched(showId: 1, season: 1, episode: 2))
        XCTAssertFalse(store.isWatched(showId: 1, season: 2, episode: 1))
        XCTAssertFalse(store.isWatched(showId: 2, season: 1, episode: 1))
    }

    // MARK: - Progress

    func testProgressNilWhenNothingWatched() async {
        XCTAssertNil(store.progress(for: 1))
    }

    func testProgressReturnsLatestWatchedEpisode() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 45)
        store.toggleWatched(showId: 1, season: 1, episode: 2, durationMinutes: 45)
        let p = store.progress(for: 1)
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.season, 1)
        XCTAssertEqual(p?.episode, 2)
    }

    func testProgressLookupCoversAllTrackedShows() async {
        store.addShow(tmdbId: 10, showName: "A")
        store.addShow(tmdbId: 20, showName: "B")
        store.toggleWatched(showId: 10, season: 2, episode: 3, durationMinutes: 30)
        let lookup = store.progressLookup
        XCTAssertEqual(lookup[10]?.season, 2)
        XCTAssertEqual(lookup[10]?.episode, 3)
        XCTAssertNil(lookup[20])
    }

    // MARK: - Stats

    func testTotalEpisodesWatched() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 40)
        store.toggleWatched(showId: 1, season: 1, episode: 2, durationMinutes: 40)
        XCTAssertEqual(store.totalEpisodesWatched, 2)
    }

    func testTotalSeasonsWatched() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 40)
        store.toggleWatched(showId: 1, season: 2, episode: 1, durationMinutes: 40)
        store.toggleWatched(showId: 2, season: 1, episode: 1, durationMinutes: 40)
        XCTAssertEqual(store.totalSeasonsWatched, 3)
    }

    func testTotalSeasonsCountsUniqueShowSeasonPairs() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 40)
        store.toggleWatched(showId: 1, season: 1, episode: 2, durationMinutes: 40)
        XCTAssertEqual(store.totalSeasonsWatched, 1)
    }

    func testTotalWatchMinutes() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 45)
        store.toggleWatched(showId: 1, season: 1, episode: 2, durationMinutes: 30)
        XCTAssertEqual(store.totalWatchMinutes, 75)
    }

    func testTotalShowsWatched() async {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 40)
        store.toggleWatched(showId: 1, season: 1, episode: 2, durationMinutes: 40)
        store.toggleWatched(showId: 2, season: 1, episode: 1, durationMinutes: 40)
        XCTAssertEqual(store.totalShowsWatched, 2)
    }

    // MARK: - markWatched via Episode

    func testMarkWatchedEpisodeCreatesWatchEvent() async {
        let ep = Episode(
            id: UUID(), tmdbShowId: 99, showName: "Show",
            title: "Ep", season: 1, episodeNumber: 3,
            durationMinutes: 50, seasonEpisodeCount: 10,
            thumbnailURL: nil, badge: nil, isWatched: false
        )
        store.markWatched(episode: ep)
        XCTAssertTrue(store.isWatched(showId: 99, season: 1, episode: 3))
        XCTAssertEqual(store.totalWatchMinutes, 50)
    }
}
