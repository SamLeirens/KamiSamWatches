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

    // MARK: - lastWatchedAt

    func testLastWatchedAtNilForShowWithNoEvents() {
        XCTAssertNil(store.lastWatchedAt[99])
    }

    func testLastWatchedAtPopulatedAfterMarkingWatched() {
        let ep = Episode(
            tmdbShowId: 1, showName: "Show", title: "Ep",
            season: 1, episodeNumber: 1, durationMinutes: 30,
            seasonEpisodeCount: 10, thumbnailURL: nil, airDate: nil,
            badge: nil, isWatched: false
        )
        store.markWatched(episode: ep)
        XCTAssertNotNil(store.lastWatchedAt[1])
    }

    func testLastWatchedAtReflectsMostRecentEvent() {
        let older = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 1, durationMinutes: 30)
        older.watchedAt = Date(timeIntervalSinceReferenceDate: 1000)
        let newer = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 2, durationMinutes: 30)
        newer.watchedAt = Date(timeIntervalSinceReferenceDate: 2000)
        store.importData(shows: [(tmdbId: 1, name: "Show")], events: [older, newer])
        XCTAssertEqual(store.lastWatchedAt[1], Date(timeIntervalSinceReferenceDate: 2000))
    }

    func testLastWatchedAtTracksPerShow() {
        let ep1 = WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: 1, durationMinutes: 30)
        ep1.watchedAt = Date(timeIntervalSinceReferenceDate: 1000)
        let ep2 = WatchEvent(tmdbShowId: 2, season: 1, episodeNumber: 1, durationMinutes: 30)
        ep2.watchedAt = Date(timeIntervalSinceReferenceDate: 2000)
        store.importData(shows: [(tmdbId: 1, name: "A"), (tmdbId: 2, name: "B")], events: [ep1, ep2])
        XCTAssertEqual(store.lastWatchedAt[1], Date(timeIntervalSinceReferenceDate: 1000))
        XCTAssertEqual(store.lastWatchedAt[2], Date(timeIntervalSinceReferenceDate: 2000))
    }

    // MARK: - markWatched via Episode

    func testMarkWatchedEpisodeCreatesWatchEvent() async {
        let ep = Episode(
            tmdbShowId: 99, showName: "Show",
            title: "Ep", season: 1, episodeNumber: 3,
            durationMinutes: 50, seasonEpisodeCount: 10,
            thumbnailURL: nil, airDate: nil, badge: nil, isWatched: false
        )
        store.markWatched(episode: ep)
        XCTAssertTrue(store.isWatched(showId: 99, season: 1, episode: 3))
        XCTAssertEqual(store.totalWatchMinutes, 50)
    }

    // MARK: - seasonProgress

    func testSeasonProgressNilWhenTotalIsNil() {
        XCTAssertNil(store.seasonProgress(showId: 1, season: 1, totalEpisodes: nil))
    }

    func testSeasonProgressNilWhenTotalIsZero() {
        XCTAssertNil(store.seasonProgress(showId: 1, season: 1, totalEpisodes: 0))
    }

    func testSeasonProgressZeroWhenNoneWatched() {
        XCTAssertEqual(store.seasonProgress(showId: 1, season: 1, totalEpisodes: 10), 0.0)
    }

    func testSeasonProgressFractionWhenSomeWatched() throws {
        store.toggleWatched(showId: 1, season: 1, episode: 1, durationMinutes: 45)
        store.toggleWatched(showId: 1, season: 1, episode: 2, durationMinutes: 45)
        let p = store.seasonProgress(showId: 1, season: 1, totalEpisodes: 4)
        XCTAssertEqual(try XCTUnwrap(p), 0.5, accuracy: 0.001)
    }

    func testSeasonProgressClampedAtOne() {
        for ep in 1...5 {
            store.toggleWatched(showId: 1, season: 1, episode: ep, durationMinutes: 45)
        }
        // Un-toggle then re-toggle to simulate dedup bypass by using importData
        let events = (6...8).map { ep -> WatchEvent in
            WatchEvent(tmdbShowId: 1, season: 1, episodeNumber: ep, durationMinutes: 45)
        }
        store.importData(shows: [], events: events)
        let p = store.seasonProgress(showId: 1, season: 1, totalEpisodes: 5)
        XCTAssertEqual(p, 1.0)
    }
}
